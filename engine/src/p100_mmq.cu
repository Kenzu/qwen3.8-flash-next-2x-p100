// Adapt the pinned ggml Pascal IQ4_NL MMQ tiles to Strata's GPU-resident expert jobs.
#if FNX_ARCH == 60 && FNX_NCARD == 2 && !FNX_HIP
#include "p100_mmq.hpp"
#include "mmq.cuh"
#include <stdexcept>
#include <string>

namespace fnx {
namespace {
constexpr int tokens_per_tile = 16;
constexpr int rows_per_tile = 64;
constexpr int warps = 8;
constexpr int group_size = 32;

struct PackedGroup {
    float scale;
    int8_t values[group_size];
};
static_assert(sizeof(PackedGroup) == 36);

// ggml's D4 layout uses a FP32 scale for each group of 32. Pack each source row
// once; different experts may select the same input row for gate and up.
__global__ void pack_rows(const half* input, PackedGroup* packed, int groups) {
    const int group = blockIdx.x * warps + threadIdx.y;
    if (group >= groups) return;
    const int lane = threadIdx.x;
    const float value = __half2float(input[size_t(group) * group_size + lane]);
    float peak = fabsf(value);
    for (int step = 16; step; step /= 2)
        peak = fmaxf(peak, __shfl_xor_sync(0xffffffffu, peak, step));
    const float inv = peak == 0 ? 0 : 127.0f / peak;
    packed[group].values[lane] = int8_t(roundf(value * inv));
    if (lane == 0) packed[group].scale = peak == 0 ? 0 : 1.0f / inv;
}

__global__ __launch_bounds__(256, 2) void iq4_jobs(
        const char* weights, const char* const* expert_ptrs, size_t expert_stride, int weight_stride,
        int width, int rows, const BigJob* jobs, const int* count, const PackedGroup* packed, float* out) {
    constexpr auto type = GGML_TYPE_IQ4_NL;
    constexpr int J = tokens_per_tile, I = rows_per_tile;
    constexpr auto sizes = mmq_get_dp4a_tile_x_sizes(type, I);
    static_assert(ggml_cuda_mmq_get_nthreads(type, J, true) == warps * 32);
    static_assert(ggml_cuda_mmq_get_I(type, J, true) == I);
    static_assert(ggml_cuda_mmq_get_K_vram(type, J, true) == MMQ_ITER_K);
    static_assert(sizeof(block_q8_1_mmq) == MMQ_TILE_Y_K * sizeof(int));
    __shared__ int tile_x[sizes.qs + sizes.dm + sizes.sc];
    __shared__ block_q8_1_mmq tile_y[J];

    if (int(blockIdx.y) >= *count) return;
    const BigJob& job = jobs[blockIdx.y];
    const int token = int(blockIdx.z) * J;
    if (token >= job.n) return;
    const int row = int(blockIdx.x) * I;
    const int last_row = min(I, rows - row) - 1;
    const int last_token = min(J, job.n - token) - 1;
    const char* expert = expert_ptrs ? expert_ptrs[job.w] : weights + size_t(job.w) * expert_stride;
    const int groups_per_row = width / group_size;
    const int lane = threadIdx.x;
    float sum[I * J / (warps * 32)] = {};

    for (int first = 0; first < width; first += MMQ_ITER_K) {
        // The down projection has 320 columns per card. Slide the last full
        // weight tile back into the row and zero the already-counted input groups.
        const int start = min(first, width - MMQ_ITER_K);
        ggml_cuda_mmq_load_tiles_iq4_nl<type, J, true>(
            expert, tile_x, row * weight_stride + start / group_size, last_row, weight_stride);
        for (int half_tile = 0; half_tile < 2; ++half_tile) {
            for (int j = threadIdx.y; j < J; j += warps) {
                const int base = start + half_tile * QK8_1_MMQ;
                const int column = base + lane * 4;
                const int source = job.y[token + min(j, last_token)];
                const PackedGroup* src = packed + size_t(source) * groups_per_row;
                int word = 0;
                if (column >= first)
                    memcpy(&word, &src[column / group_size].values[column % group_size], sizeof(word));
                reinterpret_cast<int*>(tile_y[j].qs)[lane] = word;
                if (lane < 4) {
                    const int k = base + lane * group_size;
                    tile_y[j].d4[lane] = k >= first ? src[k / group_size].scale : 0.0f;
                }
            }
            __syncthreads();
            ggml_cuda_mmq_vec_dot_q8_0_q8_1_dp4a<type, J, true>(
                tile_x, reinterpret_cast<const int*>(tile_y), sum, half_tile * MMQ_TILE_NE_K);
            __syncthreads();
        }
    }
    ggml_cuda_mmq_write_back_dp4a<type, J, true>(
        sum, job.out + token, out + row, nullptr, rows, last_row, last_token);
}

void check_launch(const char* kernel) {
    const auto error = cudaGetLastError();
    if (error != cudaSuccess) throw std::runtime_error(std::string(kernel) + ": " + cudaGetErrorString(error));
}
}  // namespace

void p100_mmq(const DW& w, size_t stride, const BigJob* jobs, const int* count, int cap,
              const uint16_t* x, int input_rows, float* out, void* scratch, void* stream) {
    if (w.type != T_IQ4_NL || w.n_in < MMQ_ITER_K || w.n_in % group_size ||
        w.row_bytes != size_t(w.n_in / group_size) * sizeof(block_iq4_nl))
        throw std::runtime_error("P100 MMQ requires compact IQ4_NL rows of at least 256 columns");
    auto* packed = static_cast<PackedGroup*>(scratch);
    const int groups = input_rows * (w.n_in / group_size);
    const dim3 threads(32, warps);
    const auto s = static_cast<cudaStream_t>(stream);
    pack_rows<<<(groups + warps - 1) / warps, threads, 0, s>>>(reinterpret_cast<const half*>(x), packed, groups);
    check_launch("P100 MMQ activation pack");
    const dim3 grid((w.n_out + rows_per_tile - 1) / rows_per_tile, cap,
                    (PF_JOB + tokens_per_tile - 1) / tokens_per_tile);
    iq4_jobs<<<grid, threads, 0, s>>>(static_cast<const char*>(w.p), w.ep, stride, int(w.row_bytes / sizeof(block_iq4_nl)),
                                      w.n_in, w.n_out, jobs, count, packed, out);
    check_launch("P100 IQ4_NL MMQ");
}
}  // namespace fnx
#endif
