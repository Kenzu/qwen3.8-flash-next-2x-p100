# Swift 1.5 IQ4_NL on X99

**System** · Xeon E5-1650 v4 · 128 GB DDR4-2400 · Tesla P100 PCIe 16 GB, Gen3 ×8, 185 W/card · Samsung 970 EVO NVMe · Debian 13.7 · NVIDIA 580.196.07 · CUDA 12.9.86.

**X99 engine** · Foghorn (Strata P100 port) · 524,288-token context · batch 1 · exact routing · common Qwen MTP draft head, K=4 · lookup 15, four sources · six prefill chunks per pass. [X99 build](https://github.com/Kenzu/qwen3.8-flash-next-2x-p100/commit/6080c570900170c3824d1036e58ad184d6f42a34)

**Developer reference** · HPE DL380 Gen10 · dual Xeon Bronze 3106 · 96 GB DDR4 · 2 × Tesla P100 16 GB, Gen3 ×16, 185 W/card · CUDA 12.4 · upstream IQ3_S profile. [Foghorn benchmark](https://github.com/Megla123/foghorn/blob/cbd4955d43130530c3c87e3c882fb6d76b1a0e41/bench/bench.py)

**Checkpoints** · [ISTA-DASLab GSQ-RCO IQ3_S](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/tree/ed59f92082b1e93c0e96d60a8b11aab089b52f09) · [UkisAI Swift 1.5 IQ4_NL](https://huggingface.co/ukisai/Swift-1.5-Qwen3.8-Flash-Next-GGUF/tree/0142554c963a8653912c0c8283f05f13f63653f3/IQ4_NL).

| System | GPUs | Model | Fresh writing, tok/s | Python edit, tok/s | Markdown edit, tok/s | 38,862-token prefill, tok/s | Writing after prefill, tok/s | Post-run edits passed |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| HPE (developer) | 2 | ISTA-DASLab GSQ-RCO IQ3_S | 66.45 | 110.65 | 115.80 | 1012.1 | 61.5 | — |
| X99 | 2 | ISTA-DASLab GSQ-RCO IQ3_S | 59.64 | 85.20 | 88.75 | 987.4 | 51.0 | 2/2 |
| X99 | 2 | Swift 1.5 IQ4_NL | 45.77 | 54.20 | 53.60 | 980.2 | 35.6 | 1/2 |
| X99 | 3 | ISTA-DASLab GSQ-RCO IQ3_S | 76.65 | 142.85 | 146.75 | 1105.3 | 76.6 | 2/2 |
| X99 | 3 | Swift 1.5 IQ4_NL | 66.25 | 112.75 | 121.00 | 1096.5 | 55.2 | 1/2 |
