// Optional two-rank CUDA collectives. The default executable has no NCCL dependency.
#pragma once
#include <nccl.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <stdexcept>
#include <string>
namespace fnx {
inline void nccl_check(ncclResult_t result, const char* what) {
    if (result != ncclSuccess)
        throw std::runtime_error(std::string(what) + ": " + ncclGetErrorString(result));
}
struct P100Nccl {
    ncclComm_t comm[2]{};
    bool decode = false, prefill = false;
    bool prefill_group = false;
    bool decode_logged = false, prefill_logged = false, scatter_logged = false;
    ~P100Nccl() {
        for (auto c : comm) if (c) ncclCommDestroy(c);
    }
};
} // namespace fnx
