# TinyNPU Architecture Decision Record (ADR) Log

This document records every significant architectural decision made during TinyNPU development.
Each entry follows the ADR format: Context → Decision → Rationale → Alternatives → Trade-offs.

---

## ADR-001: Dataflow Selection — Weight-Stationary

**Date**: 2026-07-29
**Status**: Accepted

### Context

The systolic array requires a dataflow strategy that determines which operands (weights, activations, partial sums) remain stationary in PEs and which ones are streamed.

The three canonical dataflows are:
- **Weight-Stationary (WS)**: Weights preloaded into PEs; activations stream through; partial sums flow out
- **Output-Stationary (OS)**: Partial sums stay in PEs; weights and activations both streamed
- **Row-Stationary (RS)**: Rows of computation mapped per PE to maximize all data reuse simultaneously (Eyeriss)

### Decision

**Weight-Stationary (WS) dataflow** is selected for TinyNPU v1.

### Rationale

1. **FPGA-friendly**: WS requires only one stationary buffer per PE (the weight register). No multi-directional interconnect needed.
2. **Simplicity**: WS topology is a regular mesh — easy to parameterize, synthesize, and verify.
3. **Sensor-stream compatibility**: Activations arrive as a continuous stream from the sensor interface — WS naturally accommodates streaming activations.
4. **Industry validation**: Google TPU v1 (Jouppi et al., 2017) uses WS at scale with proven results.
5. **Low weight-energy**: Once weights are loaded, no repeated DRAM access for weights during a layer — critical for power-constrained FPGA.

### Alternatives Considered

| Dataflow | Why Not Chosen |
|----------|----------------|
| Output-Stationary | Requires both weights AND activations to be streamed simultaneously — doubles memory bandwidth pressure per cycle |
| Row-Stationary (Eyeriss) | Superior energy efficiency but requires complex, irregular 2D mesh routing that maps poorly to FPGA fabric; better suited for ASIC |
| No-Local-Reuse | Maximum flexibility but no data reuse at PE level — unsuitable for latency-sensitive applications |

### Trade-offs

**Advantages of WS**:
- Weight-fetch energy amortized over all activations in a layer
- Simple, regular datapath → fast synthesis, predictable timing
- Activation streaming natural for sensor-driven workloads

**Disadvantages of WS**:
- For large layers, weight reloading between layers adds latency
- Activation data must be available in organized column order — requires pre-buffering
- Less energy-efficient than RS for large models (Eyeriss paper shows ~2.5× energy penalty vs RS at scale)

### References

- Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit," ISCA 2017
- Chen et al., "Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep CNNs," JSSC 2017
- Gao et al., "TETRIS: Scalable and Efficient Neural Network Acceleration with 3D Memory," ASPLOS 2017

---

## ADR-002: Arithmetic Precision — INT8

**Date**: 2026-07-29
**Status**: Accepted

### Context

Inference precision determines compute density, memory bandwidth, and model accuracy. Options range from FP32 down to binary.

### Decision

**INT8 (8-bit signed integer)** for both weights and activations. **INT32** accumulator to prevent overflow during MAC chains.

### Rationale

1. **DSP48E1 efficiency**: Spartan-7's DSP48E1 natively supports 18×25-bit signed multiply. INT8 can pack two INT8×INT8 into a single DSP48 with careful arrangement — doubles effective throughput.
2. **4× memory bandwidth** vs FP32 — critical for BRAM-limited Spartan-7.
3. **Quantization ecosystem**: TensorFlow Lite, ONNX Runtime, and PyTorch all support INT8 post-training quantization (PTQ). Avoids custom training workflow.
4. **<1% accuracy drop** on most CNNs with proper per-channel INT8 quantization (Jacob et al., 2018).
5. **Industry standard**: Used in TPU, Eyeriss, NVDLA, ARM Ethos-U.

### Alternatives Considered

| Precision | Reason Not Primary |
|-----------|-------------------|
| FP16/BF16 | No native FP16 DSP in Spartan-7; would require LUT-based implementation → too slow/costly |
| INT4 | Future work; INT8 is the validated baseline |
| INT16 | Less compact than INT8; not needed for most vision tasks |
| Binary/Ternary | Severe accuracy loss for complex detection tasks; FINN targets this domain |
| FP32 | 4× memory cost; DSP48 not optimized for it |

### Trade-offs

- **Pro**: Maximum DSP utilization, minimal BRAM usage, standard toolchain support
- **Con**: Quantization-aware training may be needed for very sensitive models; INT32 accumulator takes LUT resources if not mapped to DSP cascade

### Requantization Strategy

After accumulation: `output_int8 = clamp(round((INT32_acc × M) >> N), -128, 127)`
where M/N are per-layer scale factors computed offline. This avoids any floating-point hardware on chip.

### References

- Jacob et al., "Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference," CVPR 2018
- Krishnamoorthi, "Quantizing Deep Convolutional Networks for Efficient Inference: A Whitepaper," Google, 2018

---

## ADR-003: Array Size — 8×8

**Date**: 2026-07-29
**Status**: Accepted

### Context

The systolic array size determines peak compute throughput and FPGA resource cost. Spartan-7 XC7S50 has constrained resources:
- **LUTs**: 32,600
- **DSP48E1**: 120
- **BRAM**: 75 × 36Kb = 2.7 Mb

### Decision

**8×8 systolic array** (64 PEs) for initial prototype.

### Rationale

1. **DSP budget**: Each PE requires 1 DSP48E1 for INT8 MAC. 64 PEs use 64/120 = **53% of DSP budget**, leaving headroom for control logic and AXI IP.
2. **Throughput**: 64 MACs/cycle × 200 MHz = **12.8 GOPS** — sufficient for lightweight CNN layers (MobileNet-style) at high frame rates.
3. **Verification tractability**: 8×8 is large enough to expose array-level issues but small enough to simulate quickly.
4. **Scalability path**: Parameters allow expansion to 16×16 (256 PEs) for next target FPGA (Artix-7 or Zynq).

### Resource Estimate (8×8)

| Resource | PE Array | Buffers | Control | Total Est. | Budget  |
|----------|----------|---------|---------|------------|---------|
| LUT      | ~3,000   | ~2,000  | ~1,500  | ~6,500     | 32,600  |
| DSP48    | 64       | 0       | 0       | 64         | 120     |
| BRAM     | 0        | ~20     | ~2      | ~22        | 75      |
| FF       | ~4,000   | ~1,000  | ~500    | ~5,500     | 41,000  |

**Note**: These are estimates pending actual synthesis. Significantly comfortable margin exists.

### Alternatives

| Size  | DSPs | Throughput | Decision |
|-------|------|------------|---------|
| 4×4   | 16   | 3.2 GOPS   | Too small, poor research impact |
| 8×8   | 64   | 12.8 GOPS  | ✓ Selected |
| 16×16 | 256  | 51.2 GOPS  | Exceeds Spartan-7 DSP budget (256 > 120) |

---

## ADR-004: Target Platform — Xilinx Spartan-7 XC7S50

**Date**: 2026-07-29
**Status**: Accepted

### Context

Platform choice affects resource constraints, toolchain, and IP availability.

### Decision

**Xilinx Spartan-7 XC7S50** as primary FPGA prototype platform.

### Rationale

1. **Cost**: Spartan-7 is significantly cheaper than Artix-7 or Zynq — appropriate for a university research prototype.
2. **Resource sufficiency**: As shown in ADR-003, the 8×8 array fits comfortably.
3. **Toolchain**: Vivado Design Suite is freely available (WebPACK license covers Spartan-7).
4. **ASIC-readiness**: All RTL is vendor-independent; Spartan-7 serves as the validation vehicle only.
5. **No PS/PL complexity**: Unlike Zynq, Spartan-7 is pure PL — cleaner for architecture research without ARM subsystem overhead.

### Future Migration

The parameterized RTL will migrate to:
- **16×16 array**: Xilinx Artix-7 XC7A100T (240 DSPs, 135 BRAMs)
- **ASIC**: Standard-cell synthesis using open-source (OpenROAD) or commercial flow

---

## ADR-005: Interface Strategy — AXI4 Ecosystem

**Date**: 2026-07-29
**Status**: Accepted

### Decision

Three AXI interfaces:
- **AXI4-Lite**: Control/configuration (register-mapped layer parameters, start/done signals)
- **AXI4 (Full)**: High-bandwidth DMA transfers from external memory (weights, large activation maps)
- **AXI4-Stream**: Sensor input data stream and output result stream

### Rationale

1. **Industry standard**: ARM AMBA AXI is universally understood, well-documented, and directly compatible with Xilinx AXI IP (DMA, Interconnect).
2. **Separation of concerns**: Lite for slow control, Full for burst memory, Stream for data flow — clean architectural boundary.
3. **Simulation-friendly**: cocotb has excellent AXI BFM support (`cocotbext-axi`).
4. **ASIC-portability**: AXI is foundry-independent.

---

## ADR-006: Verification Strategy

**Date**: 2026-07-29
**Status**: Accepted

### Decision

Three-tier verification:
1. **Python Golden Model** — behavioral, floating-point reference (no hardware dependencies)
2. **cocotb** — Python-driven RTL simulation with AXI BFMs (Verilator backend)
3. **SystemVerilog Assertions (SVA)** — embedded protocol and datapath correctness checks

### Rationale

- Python model provides cycle-accurate numeric ground truth for all layers
- cocotb allows reuse of Python model output as RTL stimulus/checker — single source of truth
- SVA catches protocol violations at simulation time, not post-processing

---
*This ADR log is a living document. Add new ADRs as decisions are made.*
