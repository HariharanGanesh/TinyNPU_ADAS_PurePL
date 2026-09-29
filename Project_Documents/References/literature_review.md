# TinyNPU — Literature Review
## Sensor-Aware Reconfigurable AI Accelerator for Ballistic Vision

**Author**: [Your Name]
**Date**: 2026-07-29
**Purpose**: Research-grade literature survey to contextualize TinyNPU contributions and ensure no novelty is overclaimed.

---

## 1. Foundational Neural Network Accelerators

### 1.1 Google TPU v1 (2017)

**Reference**: Jouppi, N.P. et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit," *Proceedings of ISCA 2017*, pp. 1–12.

**Key Architecture**:
- 256×256 systolic array (65,536 MACs)
- Weight-stationary dataflow
- INT8 / INT16 inference
- 700 MHz @ 28nm ASIC
- 92 TOPS peak (INT8)

**Relevance to TinyNPU**:
- TinyNPU uses the same WS dataflow principle but at 8×8 scale
- TPU targets datacenter workloads; TinyNPU targets edge FPGA
- TPU has a dedicated matrix multiply unit (MXU); TinyNPU adopts the same concept scaled for Spartan-7

**Critical Comparison**:
- TPU: 256×256 = 65,536 PEs vs TinyNPU: 8×8 = 64 PEs (1000× difference)
- TPU operates on large batch sizes (N=128+); TinyNPU targets real-time single-frame streaming
- TPU's on-chip SRAM is 28 MB; TinyNPU uses ~22 BRAMs (~0.8 MB) — fundamental resource constraint

**TinyNPU Differentiation**:
TinyNPU cannot claim novelty over the systolic array design itself. The contribution lies in *adapting* WS systolic arrays for FPGA-constrained, latency-sensitive, sensor-streaming workloads.

---

### 1.2 Eyeriss (MIT, 2016)

**Reference**: Chen, Y.-H. et al., "Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep Convolutional Neural Networks," *IEEE JSSC*, vol. 52, no. 1, Jan 2017.

**Key Architecture**:
- 168 PEs in a 12×14 array
- Row-stationary (RS) dataflow — maximizes all three data reuse types simultaneously
- Per-PE SRAM (512B scratchpad)
- 65nm ASIC, 200 MHz, 1 TOPS/W

**Dataflow Deep Dive — Row-Stationary**:
RS maps one row of a filter and one row of an input feature map to one PE. This maximizes:
- **Weight reuse**: same filter row reused across output columns
- **Input reuse**: same input row reused across filter positions
- **Partial sum accumulation**: local within PE

RS is provably more energy-efficient than WS for large CNNs (see Eyeriss paper Fig. 11). However:
- RS requires a complex 2D mesh with non-uniform interconnect — maps poorly to FPGA routing fabric
- WS has simpler, more regular interconnect → better for FPGA (faster P&R, more predictable timing)

**TinyNPU Position**:
TinyNPU explicitly chooses WS over RS because FPGA routing predictability and synthesis simplicity outweigh energy savings at this scale. This is a justified, defensible trade-off for an FPGA prototype.

---

### 1.3 DianNao Family (ICT/Inria, 2014–2016)

**Reference**: Chen, T. et al., "DianNao: A Small-Footprint High-Throughput Accelerator for Ubiquitous Machine-Learning," *ASPLOS 2014*.

**Variants**:
- **DianNao**: Single-chip NN accelerator, 65nm, 452 GOPS, 485 mW
- **DaDianNao**: Multi-chip, targets eDRAM, eliminates off-chip DRAM for weights
- **ShiDianNao**: Near-sensor integration, SRAM-only, 194 GOPS/W
- **PuDianNao**: Supports multiple ML algorithms beyond CNNs

**ShiDianNao — Highest Relevance to TinyNPU**:

**Reference**: Du, Z. et al., "ShiDianNao: Shifting Vision Processing Closer to the Sensor," *ISCA 2015*.

ShiDianNao places the accelerator immediately adjacent to the image sensor, eliminating DRAM for weight and activation storage. Key points:
- 16×16 2D processing element array
- Uses only SRAM (no DRAM) — eliminates off-chip bandwidth bottleneck
- Targets real-time video (30 fps) — not high-speed ballistic vision
- 180nm ASIC (older process)

**Critical Comparison**:
TinyNPU is conceptually inspired by ShiDianNao's near-sensor philosophy but differs in:
1. **FPGA implementation** vs ShiDianNao's ASIC
2. **Ultra-high-speed target** (>1000 fps) vs ShiDianNao's 30 fps
3. **Streaming AXI interface** vs ShiDianNao's on-chip direct connection
4. **Configurable precision** (INT8 with INT4 path) vs ShiDianNao's fixed precision

**TinyNPU Can Reference This Work**: The "near-sensor" or "sensor-aware" design philosophy is established by ShiDianNao. TinyNPU's specific contribution must be the *streaming buffering strategy and AXI integration* for ultra-high-speed sensor data, which ShiDianNao does not address.

---

### 1.4 NVDLA (NVIDIA, 2017)

**Reference**: NVIDIA, "NVDLA Primer," NVIDIA Open Source, 2017. http://nvdla.org

**Architecture**:
- Full-stack inference engine (convolution, activation, pooling, batch norm)
- Multiple configurations (large/small)
- AXI4 interface (same as TinyNPU)
- INT8/INT16/FP16 support
- ASIC reference design (not FPGA-optimized)

**Key Comparison**:
| Feature | NVDLA (small) | TinyNPU |
|---------|--------------|---------|
| Array | 64 MACs | 64 MACs (8×8) |
| Precision | INT8/FP16 | INT8 (INT4 future) |
| Interface | AXI4 | AXI4 + Stream |
| Target | ASIC SoC | FPGA (Spartan-7) |
| Sensor streaming | No native stream | Yes (AXI4-Stream) |
| Config interface | CSB (custom) | AXI4-Lite |

**TinyNPU Differentiation**: NVDLA is ASIC-targeted and lacks native high-speed sensor streaming (AXI4-Stream) optimized for ultra-high-speed video. NVDLA uses a custom CSB bus, not standard AXI4-Lite. TinyNPU's FPGA-first design with standard AXI ecosystem is a different implementation domain.

---

### 1.5 MAERI (Georgia Tech, 2018)

**Reference**: Kwon, H. et al., "MAERI: Enabling Flexible Dataflow Mapping over DNN Accelerators via Reconfigurable Interconnects," *ASPLOS 2018*.

**Key Idea**: A flexible augmented reduction tree (ART) interconnect allows any dataflow (WS, OS, RS) to be configured at runtime.

**TinyNPU Comparison**:
- TinyNPU uses *fixed* WS topology — simpler, more efficient for FPGA
- MAERI's flexibility comes at the cost of complex interconnect — too expensive for Spartan-7
- If TinyNPU's "reconfigurability" means only array size and layer config, it does NOT match MAERI-style reconfigurability — this distinction must be clear in the paper

**⚠️ Caution**: Do not claim "reconfigurable dataflow" for TinyNPU. The reconfigurability in TinyNPU is *layer-parameter* reconfigurability (filter size, stride, channels), NOT dataflow reconfigurability.

---

## 2. FPGA-Specific Accelerators

### 2.1 FINN (Xilinx Research, 2017)

**Reference**: Umuroglu, Y. et al., "FINN: A Framework for Fast, Scalable Binarized Neural Network Inference," *FPGA 2017*.

**Architecture**:
- Hardware synthesis from BNN (Binary/ternary neural nets)
- Ultra-high throughput with 1-bit operations (XNOR + popcount)
- FPGA-first design
- No DSP usage (pure LUT-based for BNN)

**Comparison**:
| Feature | FINN | TinyNPU |
|---------|------|---------|
| Precision | 1-bit (BNN) | INT8 |
| Arithmetic | XNOR+popcount | MAC (DSP) |
| Accuracy | Lower (BNN penalty) | Better (INT8) |
| Throughput | Very high | Moderate |
| Target | General FPGA | Spartan-7 |

**Sensor-stream support**: FINN does not specifically optimize for ultra-high-speed sensor streaming.

**TinyNPU Position**: FINN is not directly comparable. TinyNPU targets INT8 accuracy-preserving inference, not BNN extremes.

---

### 2.2 hls4ml (CERN/FNAL, 2018+)

**Reference**: Duarte, J. et al., "Fast inference of deep neural networks in FPGAs for particle physics," *JINST 2018*.

**Key Insight**: hls4ml converts Keras/TensorFlow models to Vivado HLS for *ultra-low latency* (sub-microsecond) FPGA inference in real-time particle physics applications.

**Extremely Relevant**: This is the closest work to TinyNPU in terms of:
- Ultra-high-speed sensing domain (particle detector triggers vs ballistic vision)
- Latency-first design philosophy
- FPGA implementation

**Critical Difference**:
- hls4ml uses HLS (C/C++) not RTL — less control over micro-architecture
- hls4ml targets particle physics (1D feature vectors), not image/convolution
- TinyNPU handles 2D spatial data with systolic convolution engines

**TinyNPU Publication Opportunity**: The *ballistic vision CNN inference* problem (2D convolutional, ultra-high-speed) is NOT well addressed in existing FPGA literature. This is a genuine gap.

---

### 2.3 EfficientNet/MobileNet FPGA Deployments

Multiple papers deploy MobileNetV2/EfficientNet on Xilinx FPGAs:
- Hu et al., FPGA 2019: Depthwise separable convolution on Zynq
- Li et al., DAC 2019: Automated mapping of MobileNet to FPGAs

**Relevance**: These papers typically use Zynq (with ARM PS) for software-hardware co-design. TinyNPU is pure-PL, which means ALL control logic must be in RTL — harder but more architecturally clean and ASIC-portable.

---

## 3. Ballistic Vision / High-Speed Imaging AI

### 3.1 High-Speed Imaging Overview

High-speed ballistic vision applications typically require:
- Frame rates: **1,000–100,000 fps** (ballistic events last 1–10 ms)
- Resolution: Low-to-medium (512×512 or smaller for embedded)
- Latency constraint: **<1 ms** for real-time control/interception applications

### 3.2 Existing Work

**Camera Systems**: Photron FASTCAM, Vision Research Phantom — commercial high-speed cameras, no on-sensor AI.

**Ballistic Detection Research** (Academic):
- Limited published work specifically on *on-chip AI* for ballistic vision
- Most work uses off-chip GPU processing (not real-time embedded)
- No known FPGA-based AI accelerator specifically designed for ballistic trajectory estimation (as of 2024 literature)

**High-Speed Vision AI (Adjacent Works)**:
- Gallego et al., "Event-based Vision: A Survey," TPAMI 2022 — Event cameras for high-speed vision (different sensor modality)
- Li et al., "High Speed Video Object Detection," CVPR Workshop 2018 — GPU-based, not embedded

### 3.3 TinyNPU's Gap in Literature

**The gap**: No published FPGA AI accelerator optimized for *streaming, ultra-high-speed, ballistic vision* inference exists in open literature.

**Justifiable Claims**:
1. ✅ First FPGA AI accelerator with AXI4-Stream interface specifically designed for high-speed ballistic sensor data
2. ✅ Novel double-buffering + streaming pipeline designed for >1000 fps sensor throughput
3. ✅ INT8 inference with sub-millisecond latency characterization on Spartan-7 for ballistic-class frame rates
4. ⚠️ "Novel systolic array design" — NOT justifiable. WS systolic arrays are well-established.
5. ⚠️ "Novel INT8 quantization" — NOT justifiable. INT8 is industry standard.

---

## 4. Depthwise Separable Convolution on Systolic Arrays

### 4.1 The Challenge

Standard depthwise convolution (DW-Conv) has a **channel-independent structure**: each output channel is computed from exactly one input channel. This means:

- In a standard WS systolic array, most PEs are idle during DW-Conv
- An 8×8 array with kernel 3×3 only uses 9 PEs (1 per kernel element) per channel
- Utilization = 9/64 = **14%** — very poor

### 4.2 Known Solutions

1. **Channel folding**: Map multiple channels to the array simultaneously
2. **PE repurposing**: Treat DW-Conv as 1D convolution streamed across the array
3. **Dedicated DW-Conv engine**: Separate hardware unit alongside the systolic array (Eyeriss v2 approach)

**Reference**: Chen, Y.-H. et al., "Eyeriss v2: A Flexible Accelerator for Emerging Deep Neural Networks on Mobile Devices," *IEEE JETCAS 2019*.

### 4.3 TinyNPU Strategy

Initial approach: **Channel folding** within the WS array. Multiple input channels mapped simultaneously across PE rows.

**This is a research problem worth documenting**: The handling of depthwise convolution on a WS array without a separate engine is a known challenge. TinyNPU's approach should be documented, even if it is a known technique.

---

## 5. Summary: What TinyNPU Can and Cannot Claim

| Claim | Validity | Reason |
|-------|----------|--------|
| Novel WS systolic array | ❌ | Established since TPU (2017) |
| Novel INT8 quantization | ❌ | Established; Jacob et al. 2018 |
| Novel AXI4 interface | ❌ | Industry standard |
| FPGA impl. for ballistic vision AI | ✅ | Gap confirmed in literature |
| Streaming architecture for >1000 fps | ✅ | Not addressed in existing accelerators |
| Latency characterization on Spartan-7 | ✅ | Novel platform+application combination |
| Double-buffer for sensor-streaming | ⚠️ | Double buffering is known; *sensor-aware* application is novel |
| Reconfigurable layer parameters | ⚠️ | Reconfigurability is common; extent/novelty depends on implementation |

---

## 6. Recommended Further Reading

1. Sze et al., "Efficient Processing of Deep Neural Networks: A Tutorial and Survey," *Proc. IEEE*, 2017
2. Dally et al., "Domain-Specific Hardware Accelerators," *CACM*, 2020
3. Qin et al., "SIGMA: A Sparse and Irregular GEMM Accelerator with Flexible Interconnects," *HPCA 2020*
4. Parashar et al., "SCNN: An Accelerator for Compressed-Sparse CNNs," *ISCA 2017*
5. Kwon et al., "Understanding Reuse, Performance, and Hardware Cost of DNN Dataflow," *MICRO 2019* (Timeloop/Accelergy)

---

*This literature review is a living document. Update with new references as the project progresses.*
