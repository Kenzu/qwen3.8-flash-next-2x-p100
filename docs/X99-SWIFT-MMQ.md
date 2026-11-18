# Swift 1.5 IQ4_NL · X99 · Two Tesla P100s

Xeon E5-1650 v4 · 128 GB DDR4-2400 · 2 × Tesla P100 16 GB, PCIe 3.0 ×8, 185 W/card · Samsung 970 EVO NVMe · Debian 13.7 · NVIDIA 580.196.07 · CUDA 12.9.

UkisAI Swift 1.5 Qwen3.8-Flash-Next IQ4_NL · Foghorn · 524,288-token context · batch 1 · MTP K=4 · lookup 15, four sources · host ring. One full benchmark per configuration.

| Engine | Fresh (tok/s) | Python edit (tok/s) | Markdown edit (tok/s) | 38,862-token prefill (tok/s) | Writing after prefill (tok/s) | First content (s) | Edits passed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Original engine | 45.77 | 54.20 | 53.60 | 980.2 | 35.6 | — | 1/2 |
| MMQ off | 45.82 | 54.10 | 53.60 | 982.9 | 35.7 | 35.46 | 1/2 |
| MMQ on | 45.92 | 53.90 | 53.90 | 541.4 | 35.5 | 64.06 | 1/2 |
| MMQ on vs off | +0.2% | -0.4% | +0.6% | -44.9% | -0.6% | +80.7% | — |

First content is wall time to the first visible text in a separate streamed request (34,518 prompt tokens).
