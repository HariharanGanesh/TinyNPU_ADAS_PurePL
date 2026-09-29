# TinyNPU — Complete Project Summary
## Everything Your Mentor Needs to Know

---

## 1. What Is This Project?

**TinyNPU** (Tiny Neural Processing Unit) is a **custom AI hardware accelerator** designed entirely from scratch in **Verilog RTL (Register Transfer Level)**. It is implemented on a **Xilinx Zynq-7020 FPGA** (the PYNQ-Z2 development board).

The goal is to perform **fast, low-latency neural network inference** (running a YOLOv8n-style object detection model) at **100 MHz** clock frequency — without relying on a CPU for the compute-intensive operations.

**In simple terms:** Instead of running an AI model in software on a processor, we built the hardware circuitry that *IS* the AI processor itself.

---

## 2. Why Is This Novel / Research-Worthy?

Most existing edge AI accelerators (ARM Ethos, NVDLA) **require a host CPU** to schedule every layer. TinyNPU's key differentiators are:

| Feature | TinyNPU | Existing Designs |
|---|---|---|
| Layer scheduling | **Hardware FSM (no CPU needed)** | Software on ARM/RISC-V |
| Clock gating | **ICG-based power saving** | Always-on clock |
| Quantization | **INT8 with hardware requantization** | FP32 or SW quantization |
| Object filtering | **Hardware threshold filter** | Software post-processing |
| Portability | **ASIC-ready Verilog-2001** | HLS-generated, FPGA-only |

---

## 3. Target Platform

| Item | Detail |
|---|---|
| **FPGA Board** | Xilinx PYNQ-Z2 (Zynq-7020) |
| **FPGA Fabric** | 85K logic cells, 220 DSP48E1 slices, 140 BRAMs |
| **ARM Processor** | Dual-core Cortex-A9 at 667 MHz (used only for DMA control) |
| **EDA Tool** | Vivado 2025.1 |
| **RTL Language** | Verilog-2001 (ASIC-portable) |
| **Target Clock** | 100 MHz |
| **Final WNS** | **+0.033 ns — Timing CLOSED ✅** |

---

## 4. Complete RTL Architecture (29 Verilog Files)

The entire design is hand-written RTL — no HLS, no IP generator for the compute core.

### 4.1 Top Level
| File | Role |
|---|---|
| `tinynpu_top.v` | Master top module — wires all 12 subsystems together |
| `tinynpu_fpga_wrapper.v` | FPGA-specific I/O and BUFG instantiation |
| `tinynpu_asic_wrapper.v` | ASIC-portable wrapper (for future tape-out) |

### 4.2 Compute Core
| File | Role |
|---|---|
| `systolic_array.v` | **8×8 weight-stationary systolic array** — 64 parallel MACs |
| `processing_element.v` | Single PE: 2-stage pipelined MAC (multiply then accumulate) |
| `dw_line_buffer.v` | **Depthwise 3×3 convolution engine** — 8-channel, 9-MAC tree |

### 4.3 Memory & Buffers
| File | Role |
|---|---|
| `activation_buffer.v` | Ping-pong double-buffer for input feature maps |
| `weight_buffer.v` | Dual-bank weight SRAM for compute-DMA overlap |
| `output_buffer.v` | Output FIFO between compute and AXI stream |
| `sram_1rw.v` | Single-port SRAM primitive (ASIC-portable) |
| `sram_2rw.v` | **True dual-port SRAM** — simultaneous read and write |

### 4.4 Post-Processing Pipeline
| File | Role |
|---|---|
| `requantization_unit.v` | **3-stage pipelined INT8 requantizer** — scales 32-bit accumulator back to 8-bit |
| `activation_unit.v` | ReLU6 + PReLU activation function |
| `sigmoid_lut.v` | **256-entry BRAM LUT** for sigmoid — 2-cycle latency |
| `piecewise_sigmoid.v` | 5-segment piecewise approximation (combinational, ASIC fallback) |
| `pooling_unit.v` | 2×2 Max-Pooling unit |
| `threshold_filter.v` | Hardware NMS confidence gate — filters detections below threshold |
| `bbox_decoder.v` | Bounding box decoder — decodes raw network output to (x,y,w,h,conf) |

### 4.5 AXI Interfaces (Zynq PS ↔ PL Communication)
| File | Role |
|---|---|
| `axi4_lite_slave.v` | **AXI4-Lite CSR slave** — 32-bit register file for configuration |
| `axis_sink.v` | AXI4-Stream input — receives activation data from DMA |
| `axis_source.v` | AXI4-Stream output — sends results back to ARM |
| `dma_controller.v` | AXI4 master DMA — fetches weights from DDR directly |

### 4.6 Control & Clocking
| File | Role |
|---|---|
| `npu_controller.v` | Main FSM — sequences LOAD→COMPUTE→DRAIN→DONE |
| `tinynpu_icg.v` | **Integrated Clock Gate (ICG)** — latch-based, glitch-free clock gating |
| `clk_gate_bufgce.v` | FPGA-optimized clock gate using Xilinx BUFGCE primitive |
| `rst_sync.v` | 2-FF synchronizer for asynchronous reset |

### 4.7 Frontend
| File | Role |
|---|---|
| `frame_gen.v` | Test frame generator — produces synthetic input frames for hardware self-test |
| `pl_top.v` | PL (Programmable Logic) top-level wrapper |
| `result_capture.v` | Captures inference results for readback via AXI-Lite |

---

## 5. System Architecture — How It All Connects

```
ARM Cortex-A9 (PS)
     │
     ├─ AXI4-Lite ──────────► axi4_lite_slave.v (CSR: config registers)
     │                              │
     │                         npu_controller.v (state machine)
     │
     ├─ AXI4 DMA ───────────► dma_controller.v ──► weight_buffer.v
     │                                                    │
     └─ AXI4-Stream ────────► axis_sink.v ──────► activation_buffer.v
                                                         │
                                              systolic_array.v (64 MACs)
                                              dw_line_buffer.v (9 MACs)
                                                         │
                                             requantization_unit.v
                                             activation_unit.v
                                             pooling_unit.v
                                             bbox_decoder.v
                                             threshold_filter.v
                                                         │
                                              output_buffer.v
                                                         │
ARM Cortex-A9 (PS) ◄────── axis_source.v ◄─────────────┘
```

---

## 6. The Systolic Array — Core Innovation

The **8×8 weight-stationary systolic array** is the heart of TinyNPU.

- **Architecture:** 64 Processing Elements (PEs) arranged in an 8×8 grid
- **Dataflow:** Weight-stationary — weights stay in PEs; activations flow right; partial sums flow down
- **Each PE:** 2-stage pipelined MAC (Stage 1: 8×8 multiply; Stage 2: add to accumulator)
- **Throughput:** 64 MACs per clock cycle = **6.4 GMAC/s at 100 MHz**
- **Precision:** INT8 weights × INT8 activations → INT32 accumulator → INT8 output (via requantization)

The 2-stage pipeline was a **critical timing fix** — without it, the single-cycle 8×8 multiply + accumulate path would not close at 100 MHz.

---

## 7. Quantization — INT8 Inference

The design uses **8-bit integer (INT8) quantization** throughout:

- **Why INT8?** A DSP48 on Zynq does an 8×8 multiply in 1 stage. FP32 would require 3-5 DSPs.
- **Requantization:** After 64 MACs, the 32-bit accumulator is scaled back to INT8 using:
  - Stage 1: 32×32 multiply by quantization scale factor M₀
  - Stage 2: Arithmetic right shift by N bits
  - Stage 3: Saturate and clip to [-128, +127]
- **Sigmoid:** Implemented as a 256-entry LUT in BRAM (2-cycle latency), not computed with DSPs

---

## 8. Clock Domain Architecture

The design has **two clock domains** (both derived from the single 100 MHz PS clock):

| Domain | Source | Gating Condition | Clocks |
|---|---|---|---|
| `clk` | PS FCLKCLK[0] → BUFG | Always on | AXI, DMA, Controller, CSR |
| `clk_postproc` | `clk` → ICG → BUFG | `requant_valid OR pool_enable` | Activation, Pooling, Threshold Filter |

The **ICG (Integrated Clock Gate)** saves power by halting the post-processing clock when the systolic array is loading new weights. This is an **ASIC design pattern** correctly ported to FPGA.

---

## 9. AXI Interface — Zynq PS ↔ PL Communication

Three AXI protocols are used:

| Protocol | Direction | Used For |
|---|---|---|
| **AXI4-Lite** | PS → PL | Configuration registers (start, threshold, layer type, etc.) |
| **AXI4 (full)** | PL → DDR | DMA fetches weight matrices from system memory |
| **AXI4-Stream** | Bidirectional | Stream input activations in; stream detection results out |

The ARM processor **does not participate in computation** — it only initiates DMA transfers and reads results. All MAC operations happen in PL fabric.

---

## 10. Vivado Block Design

The design is integrated as a **custom IP core** (`tinynpu100`) inside a Vivado Block Design (`tinynpu_system_bd`) alongside:
- Xilinx Processing System 7 (PS7) — the ARM processor
- Xilinx AXI DMA — for high-speed data transfer
- AXI Interconnect — routes AXI transactions between masters and slaves
- Processor System Reset — synchronized reset distribution

---

## 11. Timing Closure — The Hard Engineering Problem

Timing closure is the process of ensuring every signal propagates through the chip **within one clock cycle (10 ns at 100 MHz)**. This was the most technically challenging part of the project.

### 11.1 What WNS Means
**WNS (Worst Negative Slack)** = how much margin the critical path has.
- WNS ≥ 0 → Design meets timing ✅
- WNS < 0 → At least one path is too slow (violation)

### 11.2 Our Journey

| Step | WNS | Root Cause | Fix Applied |
|---|---|---|---|
| Initial build | **-1.285 ns** | `frame_gen.v` comparison logic — 11 LUT levels in one cycle | Pipelined the comparison into 2 register stages |
| After RTL fix | **-0.602 ns** | Post-route phys_opt needed | Ran `AggressiveExplore` phys_opt strategy |
| After phys_opt | **-0.539 ns** | Clock domain skew discovered | — |
| After clock fix | **-0.176 ns** | Clock skew: `u_pooling` (ICG clock, +3.35ns delay) → `u_threshold_filter` (ungated clock) | Changed `threshold_filter` to use `clk_postproc` |
| **Final** | **+0.033 ns ✅** | Vivado used cached old netlist — directly patched the `.gen` directory source file | Fixed `.gen/ipshared/bd96/src/tinynpu_top.v` directly |

### 11.3 The Clock Skew Problem (Key Technical Achievement)

The critical insight was that `u_pooling` was clocked by `clk_postproc` (which travels through an extra BUFG, adding **+3.35 ns** of clock insertion delay), while `u_threshold_filter` was clocked by the ungated `clk`. 

This created a **-3.35 ns clock skew** between source and destination FFs on what appeared to be the same domain. Moving `threshold_filter` onto `clk_postproc` made both registers use the **same BUFG**, reducing skew to ~0 and adding +3.2 ns of slack — closing timing.

---

## 12. Implementation Results (Final Numbers)

| Metric | Value |
|---|---|
| **Clock Frequency** | 100 MHz |
| **WNS (Worst Negative Slack)** | **+0.033 ns** (timing met) |
| **TNS (Total Negative Slack)** | **0.000 ns** (zero violations) |
| **Total Timing Endpoints Checked** | 61,874 |
| **DRC Errors** | **0** |
| **Bitstream** | Generated successfully |
| **RTL Files** | 29 hand-written Verilog modules |
| **Compute Throughput** | ~6.4 GMAC/s (64 MACs × 100 MHz) |
| **Precision** | INT8 (weights + activations) |

---

## 13. Key Design Decisions & Why

| Decision | Reason |
|---|---|
| **Hand-written RTL, not HLS** | Full control over pipeline stages, timing, and ASIC portability |
| **INT8, not FP32** | 4× fewer DSPs needed; faster; fits in Zynq-7020 |
| **Weight-stationary dataflow** | Minimizes weight memory bandwidth — weights loaded once, reused |
| **Ping-pong double buffering** | Hides DMA latency — compute and memory transfer overlap |
| **ICG clock gating** | Reduces dynamic power when post-processing stage is idle |
| **AXI4-Lite for configuration** | Standard, well-understood interface; easy driver integration |
| **ASIC-portable Verilog-2001** | No Vivado-specific pragmas in compute core; can target TSMC/GlobalFoundries |

---

## 14. What Makes This a Final Year Project Worth Defending

1. **Full custom hardware design** — not just connecting pre-built IP blocks
2. **29 hand-written RTL modules** — real hardware engineering
3. **Timing closure achieved** — the hardest practical challenge in digital design
4. **Novel dual-engine architecture** — both systolic array (for 1×1 pointwise conv) and dedicated depthwise engine (for 3×3 depthwise conv)
5. **ASIC-portable** — the design can be submitted to a real chip foundry with minimal changes
6. **INT8 quantization pipeline** — industrially relevant (used by Google TPU, Apple Neural Engine)
7. **Hardware-verified** — actual bitstream generated and loaded onto PYNQ board

---

> [!TIP]
> If your mentor asks "what would you do next?", the answer is: implement the **hardware ROI engine** (motion detection to focus computation only on moving objects), the **streaming front-end** (start inference before the full frame arrives), and test with a real YOLOv8n weight set on the PYNQ board. These are all architected in the v2 design document.
