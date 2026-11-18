# X99 P100 benchmark

**X99** · Xeon E5-1650 v4 (6C/12T), 128 GB DDR4-2400, 3 × Tesla P100 PCIe 16 GB at Gen3 ×8 and 185 W each, Samsung 970 EVO NVMe, Debian 13.7, NVIDIA 580.196.07, CUDA 12.9.86.

**Developer** · HPE DL380 Gen10, 2 × Xeon Bronze 3106, 96 GB DDR4, 2 × Tesla P100 PCIe 16 GB at Gen3 ×16 and 185 W each, CUDA 12.4.131.

**Model** · [ISTA-DASLab Qwen3.8-Flash-Next GSQ-RCO IQ3_S](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/tree/ed59f92082b1e93c0e96d60a8b11aab089b52f09), both GGUF shards.

**Strata** · [Upstream benchmark and developer reference](https://github.com/Megla123/qwen3.8-flash-next-2x-p100/blob/404de0a78ac044eef53fed8b46dd76639e29d089/bench/bench.py), 524,288-token context, MTP 4, lookup 15, route prior 0. All speeds in tokens/s.

## Two GPUs per system

| System and profile | Fresh writing | Python edit | Markdown edit | Prefill (38,862 tokens) | Writing after prefill |
|---|---:|---:|---:|---:|---:|
| Developer, 2 GPUs | 66.45 | 110.65 | 115.80 | 1012.1 | 61.5 |
| X99, 2 GPUs, stock (mean of 2) | 59.59 | 75.68 | 78.48 | 971.2 | 52.1 |
| X99, 2 GPUs, prefetch 2 (mean of 2) | 60.01 | 82.90 | 84.80 | 974.3 | 53.0 |
| X99, 2 GPUs, six prefill blocks | 59.65 | 75.60 | 78.90 | 991.0 | 52.7 |
| X99, 2 GPUs, prefetch 2 + six blocks | 59.90 | 83.55 | 85.35 | 990.3 | 52.2 |
| X99, 2 GPUs, prefetch 2 + four lookup sources | 59.72 | 85.00 | 87.40 | 974.3 | 52.7 |
| X99, 2 GPUs, prefetch 2 + four sources + longer proposals | 59.64 | 83.45 | 86.70 | 974.0 | 50.8 |
| X99, 2 GPUs, prefetch 2 + six blocks + four lookup sources | 59.68 | 85.10 | 87.45 | 990.6 | 51.7 |
| X99, 2 GPUs, same profile, eight-token index off | 59.71 | 85.10 | 87.45 | 988.6 | 53.0 |
| X99, 2 GPUs, same profile, eight-token index on | 59.67 | 83.75 | 86.75 | 990.5 | 51.4 |

## Three GPUs on X99

| System and profile | Fresh writing | Python edit | Markdown edit | Prefill (38,862 tokens) | Writing after prefill |
|---|---:|---:|---:|---:|---:|
| X99, 3 GPUs, prefetch 2 | 76.91 | 137.65 | 143.70 | 1093.1 | 79.7 |
