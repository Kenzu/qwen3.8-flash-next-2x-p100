# ISTA IQ3_S · 2 × Tesla P100 · NCCL

X99 · Xeon E5-1650 v4 · 128 GB DDR4-2400 · 2 × Tesla P100 PCIe 16 GB, Gen3 ×8, 185 W/card · Samsung 970 EVO NVMe · Debian 13.7 · NVIDIA 580.196.07 · CUDA 12.9 · NCCL 2.22.3.

ISTA-DASLab Qwen3.8-Flash-Next GSQ-RCO IQ3_S · Foghorn · 524,288-token context · batch 1 · MTP K=4 · lookup 15, four sources · six prefill chunks per pass. All speeds in tokens/s.

| Transport | Runs | Fresh writing | Python edit | Markdown edit | Prefill (38,862 tokens) | Writing after prefill | Edits passed |
|---|---:|---:|---:|---:|---:|---:|---:|
| Original engine | 1 | 59.56 | 85.20 | 87.50 | 989.2 | 51.0 | 2/2 |
| Host ring (same build) | 1 | 59.69 | 85.10 | 87.45 | 989.6 | 51.0 | 2/2 |
| NCCL (default, shared RAM) | 1 | 55.89 | 79.40 | 82.55 | 976.8 | 47.9 | 2/2 |
| NCCL (direct PCIe) | 1 | 55.87 | 79.95 | 82.00 | 932.3 | 48.1 | 2/2 |
| NCCL (direct PCIe) vs host ring | | -6.4% | -6.1% | -6.2% | -5.8% | -5.7% | |
