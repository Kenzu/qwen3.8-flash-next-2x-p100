#pragma once

#include "kernels.hpp"

namespace fnx {
// One FP32 scale and 32 signed bytes per activation group, owned by the prompt stream.
inline size_t p100_mmq_bytes(int rows, int width) {
    return size_t(rows) * (width / 32) * 36;
}

void p100_mmq(const DW& weights, size_t expert_stride, const BigJob* jobs, const int* job_count,
              int job_capacity, const uint16_t* input, int input_rows, float* out, void* scratch, void* stream);
}  // namespace fnx
