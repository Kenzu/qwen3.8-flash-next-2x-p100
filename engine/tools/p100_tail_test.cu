// Compare compact expert rows with the same rows explicitly padded to 64 columns.
#include "../src/kernels.hpp"
#include <cuda_fp16.h>
#include <cuda_runtime.h>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <vector>

namespace fnx {
// This test links the production MoE implementation. Its attention entry points are unused.
int qsa_maxsel() { throw std::runtime_error("unexpected attention call in MoE test"); }
void p100_moe_mode(const DW&, size_t, const BigJob*, const int*, int,
                   const uint16_t*, float*, int, void*);
}

namespace {
constexpr int output_rows = 128;
void check(cudaError_t status) {
    if (status != cudaSuccess) throw std::runtime_error(cudaGetErrorString(status));
}

template <typename T>
struct DeviceBuffer {
    T* data = nullptr;
    explicit DeviceBuffer(size_t count) { check(cudaMalloc(&data, count * sizeof(T))); }
    ~DeviceBuffer() { cudaFree(data); }
    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
};

std::vector<float> evaluate(int width, int tokens, int type,
                            const std::vector<char>& weights, const std::vector<__half>& input) {
    DeviceBuffer<char> dw(weights.size());
    DeviceBuffer<__half> dx(input.size());
    DeviceBuffer<float> dy(tokens * output_rows);
    DeviceBuffer<fnx::BigJob> dj(1);
    DeviceBuffer<int> dn(1);
    fnx::DW matrix{};
    matrix.p = dw.data;
    matrix.type = type;
    matrix.n_in = width;
    matrix.n_out = output_rows;
    matrix.row_bytes = weights.size() / output_rows;
    check(cudaMemcpy(dw.data, weights.data(), weights.size(), cudaMemcpyHostToDevice));
    check(cudaMemcpy(dx.data, input.data(), input.size() * sizeof(__half), cudaMemcpyHostToDevice));
    std::vector<float> result(tokens * output_rows);
    check(cudaMemset(dy.data, 0xff, result.size() * sizeof(float)));
    fnx::BigJob job{};
    job.n = tokens;
    for (int i = 0; i < tokens; ++i) {
        job.y[i] = tokens - 1 - i;
        job.out[i] = i;
    }
    int one = 1;
    check(cudaMemcpy(dj.data, &job, sizeof(job), cudaMemcpyHostToDevice));
    check(cudaMemcpy(dn.data, &one, sizeof(one), cudaMemcpyHostToDevice));
    fnx::p100_moe_mode(matrix, weights.size(), dj.data, dn.data, 1,
                       reinterpret_cast<const uint16_t*>(dx.data), dy.data, 7, nullptr);
    check(cudaMemcpy(result.data(), dy.data, result.size() * sizeof(float), cudaMemcpyDeviceToHost));
    return result;
}

bool compare(int type, int width, int tokens) {
    const int padded_width = (width + 63) / 64 * 64;
    const int bytes = type == fnx::T_Q8_0 ? 34 : (type == fnx::T_Q5_1 ? 24 : 18);
    std::vector<char> weights(output_rows * width / 32 * bytes);
    std::vector<char> padded_weights(output_rows * padded_width / 32 * bytes, 0);
    for (int row = 0; row < output_rows; ++row) {
        for (int block = 0; block < width / 32; ++block) {
            char* data = weights.data() + (row * (width / 32) + block) * bytes;
            __half scale = __float2half(0.015625f * (1 + (row + block) % 5));
            std::memcpy(data, &scale, sizeof(scale));
            for (int i = 2; i < bytes; ++i)
                data[i] = static_cast<char>((row * 31 + block * 17 + i * 13 + 9) & 255);
            if (type == fnx::T_Q5_1) {
                __half offset = __float2half(-0.25f);
                std::memcpy(data + 2, &offset, sizeof(offset));
            }
            std::memcpy(padded_weights.data() + (row * (padded_width / 32) + block) * bytes, data, bytes);
        }
    }
    std::vector<__half> input(tokens * width);
    std::vector<__half> padded_input(tokens * padded_width, __float2half(0));
    for (int row = 0; row < tokens; ++row) {
        for (int col = 0; col < width; ++col) {
            __half value = __float2half(float((row * 19 + col * 7) % 127 - 63) / 64);
            input[row * width + col] = value;
            padded_input[row * padded_width + col] = value;
        }
    }
    auto compact = evaluate(width, tokens, type, weights, input);
    auto padded = evaluate(padded_width, tokens, type, padded_weights, padded_input);
    for (size_t i = 0; i < compact.size(); ++i) {
        if (!std::isfinite(compact[i]) || compact[i] != padded[i]) {
            std::fprintf(stderr, "FAIL type=%d K=%d T=%d i=%zu compact=%g padded=%g\n",
                         type, width, tokens, i, compact[i], padded[i]);
            return false;
        }
    }
    return true;
}
}  // namespace

int main() {
    int cases = 0;
    for (int type : {fnx::T_Q4_0, fnx::T_IQ4_NL, fnx::T_Q5_1, fnx::T_Q8_0}) {
        for (int width : {32, 96, 160, 192, 224, 256, 320}) {
            for (int tokens : {1, 3, 7, 12, 13, 24, 25, 36, 37, 48, 49, 72, 73, 96}) {
                if (tokens > fnx::PF_JOB) continue;
                if (!compare(type, width, tokens)) return 1;
                ++cases;
            }
        }
    }
    std::printf("PASS %d compact/padded cases\n", cases);
}
