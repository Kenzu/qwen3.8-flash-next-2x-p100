// Numerical check of the production IQ4_NL prompt adapter against a scalar CPU dot product.
#include "../src/p100_mmq.hpp"
#include <cuda_fp16.h>
#include <cuda_runtime.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <vector>

namespace {
void check(cudaError_t status) {
    if (status != cudaSuccess) throw std::runtime_error(cudaGetErrorString(status));
}
template<class T> struct Buffer {
    T* p = nullptr;
    explicit Buffer(size_t n) { check(cudaMalloc(&p, n * sizeof(T))); }
    ~Buffer() { cudaFree(p); }
    Buffer(const Buffer&) = delete;
    void upload(const T* src, size_t n) { check(cudaMemcpy(p, src, n * sizeof(T), cudaMemcpyHostToDevice)); }
};
constexpr int levels[] = {-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113};
constexpr int outputs = 69;  // includes a partial 64-row weight tile
constexpr int tokens = fnx::PF_JOB + 18;

void run(int width, bool indirect) {
    const int groups = width / 32;
    const int stride = outputs * groups * 18 + 16; // exercise an inter-expert gap
    std::vector<unsigned char> weights(2 * stride);
    std::vector<__half> input(tokens * width);
    std::vector<int> quant(input.size());
    std::vector<float> scales(tokens * groups);
    for (int expert = 0; expert < 2; ++expert)
        for (int row = 0; row < outputs; ++row)
            for (int g = 0; g < groups; ++g) {
                auto* dst = weights.data() + expert * stride + (row * groups + g) * 18;
                __half d = __float2half(((expert + row + g) % 5 + 1) / 256.f);
                std::memcpy(dst, &d, 2);
                for (int n = 0; n < 16; ++n) dst[2+n] = 17 * row + 11 * expert + g * 7 + 19 * n;
            }
    for (int row = 0; row < tokens; ++row)
        for (int g = 0; g < groups; ++g) {
            const int off = row * width + 32 * g;
            float peak = 0;
            for (int k = 0; k < 32; ++k) {
                const float v = (row + g) % 9 == 0 ? 0.f : ((k * 11 + row * 7 + g) % 101 - 50) / 64.f;
                input[off+k] = __float2half(v);
                peak = std::max(peak, std::abs(v));
            }
            const float inv = peak ? 127.f / peak : 0.f;
            scales[row * groups + g] = peak ? 1.f / inv : 0.f;
            for (int k = 0; k < 32; ++k) quant[off+k] = int(std::round(__half2float(input[off+k]) * inv));
        }

    fnx::BigJob jobs[4]{};
    int pos = 0;
    for (int j = 0; j < 3; ++j) {
        jobs[j].w = j % 2;
        jobs[j].n = j == 0 ? 1 : (j == 1 ? 17 : fnx::PF_JOB);
        for (int i = 0; i < jobs[j].n; ++i, ++pos) {
            jobs[j].y[i] = (pos * 3 + 1) % tokens;  // repeats across routes
            jobs[j].out[i] = tokens - pos;           // leave output row zero untouched
        }
    }
    const int actual = 3;
    Buffer<unsigned char> w(weights.size()), scratch(fnx::p100_mmq_bytes(tokens, width));
    Buffer<const char*> ptrs(2);
    Buffer<__half> x(input.size());
    Buffer<fnx::BigJob> jb(4);
    Buffer<int> count(1);
    std::vector<float> result((tokens+1)*outputs, -1234567.f);
    Buffer<float> out(result.size());
    w.upload(weights.data(), weights.size());
    const char* table[] = {reinterpret_cast<char*>(w.p + stride), reinterpret_cast<char*>(w.p)};
    ptrs.upload(table, 2);
    x.upload(input.data(), input.size());
    jb.upload(jobs, 4);
    count.upload(&actual, 1);
    out.upload(result.data(), result.size());
    fnx::DW matrix{};
    matrix.type = fnx::T_IQ4_NL;
    matrix.p = indirect ? nullptr : w.p;
    matrix.ep = indirect ? ptrs.p : nullptr;
    matrix.row_bytes = groups * 18;
    matrix.n_in = width;
    matrix.n_out = outputs;
    fnx::p100_mmq(matrix, stride, jb.p, count.p, 4, reinterpret_cast<uint16_t*>(x.p),
                  tokens, out.p, scratch.p, nullptr);
    check(cudaMemcpy(result.data(), out.p, result.size()*sizeof(float), cudaMemcpyDeviceToHost));
    for (int r = 0; r < outputs; ++r)
        if (result[r] != -1234567.f) throw std::runtime_error("MMQ overwrote an unselected row");
    for (int j = 0; j < actual; ++j)
        for (int i = 0; i < jobs[j].n; ++i)
            for (int r = 0; r < outputs; ++r) {
                const int src = jobs[j].y[i], expert = indirect ? 1-jobs[j].w : jobs[j].w;
                double reference = 0;
                for (int g = 0; g < groups; ++g) {
                    const auto* block = weights.data()+expert*stride+(r*groups+g)*18;
                    __half d;
                    std::memcpy(&d, block, 2);
                    int dot = 0;
                    for (int k = 0; k < 32; ++k) {
                        int nibble = (block[2+k%16] >> (k < 16 ? 0 : 4)) & 15;
                        dot += levels[nibble]*quant[src*width+32*g+k];
                    }
                    reference += double(dot)*__half2float(d)*scales[src*groups+g];
                }
                const float value = result[jobs[j].out[i]*outputs+r];
                if (!std::isfinite(value) || std::abs(value-reference) > 0.0005 + 0.00005*std::abs(reference)) {
                    std::fprintf(stderr, "width=%d indirect=%d job=%d token=%d row=%d got=%g expected=%g\n",
                                 width, indirect, j, i, r, value, reference);
                    throw std::runtime_error("MMQ numerical mismatch");
                }
            }
}
} // namespace
int main() {
    for (int width : {256, 288, 320, 2560})
        for (bool indirect : {false, true}) run(width, indirect);
    std::puts("PASS: 8 IQ4_NL MMQ cases, including the two-card gate/up and down widths");
}
