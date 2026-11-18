# X99 system memory bandwidth

Xeon E5-1650 v4 · 6 cores / 12 threads · 4 × 32 GB DDR4-2400 · four populated channels · theoretical peak 76.8 GB/s. [Intel specifications](https://www.intel.com/content/www/us/en/products/sku/92994/intel-xeon-processor-e51650-v4-15m-cache-3-60-ghz/specifications.html)

## STREAM 5.10

GB/s · 64 million doubles per array · 20 iterations · median of three independent process runs. [STREAM](https://www.cs.virginia.edu/stream/)

| CPU threads | Copy | Scale | Add | Triad |
|---:|---:|---:|---:|---:|
| 1 | 23.04 | 11.54 | 11.92 | 11.94 |
| 6 | 53.63 | 32.93 | 35.32 | 35.37 |
| 12 | 51.04 | 32.45 | 35.20 | 35.39 |

## Sequential AVX2 kernels

GB/s · 64 million doubles per array · one six-second run per configuration. Controller columns report measured bus traffic on the X99.

| Threads | Kernel | Useful data | DRAM reads | DRAM writes | DRAM total |
|---:|---|---:|---:|---:|---:|
| 6 | Read only | 46.95 | 47.01 | 0.02 | 47.04 |
| 6 | Triad, ordinary stores | 35.19 | 35.21 | 11.75 | 46.96 |
| 6 | Triad, non-temporal stores | 48.31 | 32.52 | 16.15 | 48.67 |
| 12 | Read only | 43.26 | 43.24 | 0.03 | 43.27 |
| 12 | Triad, ordinary stores | 34.85 | 34.79 | 11.63 | 46.41 |
| 12 | Triad, non-temporal stores | 46.51 | 31.77 | 15.62 | 47.38 |

## System-wide DRAM reads / writes during inference

Memory-controller traffic in GB/s, averaged over one-second samples. The long request includes prefill and subsequent decoding.

| P100s | Model | Fresh writing | Python + Markdown edits | Long request |
|---:|---|---:|---:|---:|
| 2 | ISTA IQ3_S | 4.6 / 0.2 | 8.4 / 0.2 | 9.0 / 1.7 |
| 2 | Swift IQ4_NL | 6.7 / 0.2 | 10.3 / 0.2 | 9.6 / 1.7 |
| 3 | ISTA IQ3_S | 2.3 / 0.2 | 5.3 / 0.5 | 14.0 / 2.8 |
| 3 | Swift IQ4_NL | 4.9 / 0.3 | 9.7 / 0.4 | 14.2 / 2.7 |

## Pinned RAM to GPU

| System | PCIe link per P100 | Copy configuration | GB/s per P100 |
|---|---|---:|---:|
| X99 | Gen3 ×8 | 2 concurrently | 5.96–5.97 |
| X99 | Gen3 ×8 | 3 concurrently | 5.96–5.97 |
| Developer HPE | Gen3 ×16 | Per card | 11.9 (reported) |

Developer HPE · two Bronze 3106 CPUs · three 16 GB channels per socket · theoretical 51.2 GB/s per socket or 102.4 GB/s in aggregate at DDR4-2133. [Foghorn hardware](https://github.com/Megla123/foghorn/blob/cbd4955d43130530c3c87e3c882fb6d76b1a0e41/docs/GUIDE.md#the-machine) · [Intel specifications](https://www.intel.com/content/www/us/en/products/sku/123540/intel-xeon-bronze-3106-processor-11m-cache-1-70-ghz/specifications.html)
