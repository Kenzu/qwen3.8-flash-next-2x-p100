# Rust inference on X99

**System** · Xeon E5-1650 v4, 128 GB DDR4-2400, Tesla P100 PCIe 16 GB at Gen3 ×8 and 185 W, Samsung 970 EVO NVMe, Debian 13.7, NVIDIA 580.196.07, CUDA toolkit 12.9.86.

**Model** · ISTA-DASLab Qwen3.8-Flash-Next GSQ-RCO IQ3_S, both shards, revision `ed59f92`. RustingStrata v1.2.5, oxinfer `8378d99`, Atlas b470.

**Raw generation** · “The capital of France is”, 5 input tokens, 16 generated, greedy, 6 CPU threads. All four configurations produced the same text.

| Engine and device | Prefill (tok/s) | Decode (tok/s) |
|---|---:|---:|
| RustingStrata, 2 × Vulkan P100, warm routing profile, MTP off | 24.65 | 24.51 |
| RustingStrata, 2 × Vulkan P100, same initial profile, MTP 1 (shared Q8_0 head) | 10.75 | 8.19 |
| oxinfer, CUDA selected on GPU 0 | 3.0 | 2.0 |
| oxinfer, CPU | 1.0 | 1.6 |

**RustingStrata native benchmark** · 24 layers per P100, 4,096-token context, 256-token chunks, up to 32 output tokens, two repetitions. Rates are mean tokens/s.

| Prompt tokens | MTP drafts | Prefill | Decode (min–max) |
|---:|---:|---:|---:|
| 128 | 0 | 14.9 | 23.6 (23.4–23.7) |
| 128 | 1 | 15.1 | 3.3 (0.0–6.6) |
| 512 | 0 | 25.7 | 23.7 (23.6–23.9) |
| 512 | 1 | 25.7 | 18.8 (18.5–19.0) |

**Atlas b470** · 0 output tokens. The GGUF loader rejected `qwen4exp`. A separate Gemma 4 kernel check reported no shipped target for `sm_60`.
