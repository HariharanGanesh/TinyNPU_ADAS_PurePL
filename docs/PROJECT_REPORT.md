---
# Technical Project Report
# TinyNPU200: FPGA-Based Neural Processing Unit IP Core

**Author:** Hariharan Ganesh  
**Email:** hariharanganesh67@gmail.com  
**Year:** 2026  
**Target Platform:** Xilinx Zynq-7020 (PYNQ-Z2)  
**Vivado Version:** 2025.1  

> Copyright (c) 2026 Hariharan Ganesh. All rights reserved.
> This document is publicly available for academic and evaluation purposes.
> Use of the actual IP requires authorization. See ACCESS.md.

---

## Abstract

This report presents the TinyNPU200, a custom FPGA-based Neural Processing Unit (NPU) IP core implemented in synthesizable Verilog-2001, targeting the Xilinx Zynq-7020 SoC on the PYNQ-Z2 development board. The TinyNPU200 implements a 20x8 weight-stationary systolic array of 160 Processing Elements (PEs), each mapped to a DSP48E1 MAC unit, enabling INT8 neural network inference acceleration. The IP exposes industry-standard AXI4-Lite (control), AXI4-Full (DMA), and AXI4-Stream (data) interfaces, making it suitable for integration with Zynq Processing System (PS) and third-party IP in Vivado Block Design. The design has been functionally verified using a 5-test SystemVerilog testbench, with all tests passing under Vivado XSim behavioral simulation.

---

## 1. Introduction

Neural network inference at the edge requires dedicated hardware accelerators capable of delivering high throughput within tight power and area constraints. General-purpose CPUs and GPUs are poorly suited for embedded, real-time inference workloads. Field-Programmable Gate Arrays (FPGAs) offer a compelling middle ground: they provide reconfigurable hardware that can be optimized for specific neural network operators (convolution, pooling, activation functions) while remaining flexible for future model updates.

This project presents the TinyNPU200, an original FPGA NPU IP core developed as a final year engineering project. The design targets INT8 quantized neural network inference, specifically CNN-based tasks including object detection (YOLOv8-style anchor-free detection), image classification, and face embedding similarity computation.

---

## 2. Motivation and Problem Statement

Existing FPGA neural network accelerators are typically either:
- Too large and complex for student/academic-scale projects
- Based on High-Level Synthesis (HLS) tools that abstract away RTL-level design
- Closed-source commercial IP
- Targeting large FPGA devices unavailable to academic users

The TinyNPU200 addresses this by providing a fully handwritten RTL implementation, targeting the widely-available PYNQ-Z2 (Zynq-7020), with clear module boundaries, documented interfaces, and a complete verification environment.

---

## 3. Objectives

1. Design a weight-stationary systolic array NPU in synthesizable RTL
2. Support INT8 quantized inference with INT32 accumulation
3. Implement standard AXI4 interfaces for easy SoC integration
4. Support runtime-configurable layer parameters via AXI4-Lite CSRs
5. Implement post-processing pipeline: requantization, activation functions, pooling, and YOLOv8 bounding box decoding
6. Achieve functional verification through simulation
7. Package as a reusable Vivado IP

---

## 4. System Architecture

### 4.1 Top-Level Overview

The TinyNPU200 is implemented as a single Vivado IP (module: tinynpu_top) integrating 15 submodules:

| Module | Function |
|---|---|
| axi4_lite_slave | AXI4-Lite CSR interface (32 registers) |
| dma_controller | AXI4-Full DMA master |
| npu_controller | Main FSM orchestrator |
| axis_sink | AXI-Stream input with spatial crop |
| activation_buffer x20 | Per-row ping-pong BRAM buffers |
| weight_buffer | Dual-bank ping-pong weight BRAM |
| systolic_array | 20x8 PE grid |
| dw_line_buffer | 3x3 depthwise conv engine |
| requantization_unit | INT32 to INT8 with per-channel scale/shift/bias |
| activation_unit | 5-mode activation function |
| pooling_unit | 2x2 MaxPool/AvgPool/Bypass |
| bbox_decoder | YOLOv8 anchor-free bounding box decoder |
| threshold_filter | Confidence gate |
| output_buffer | Output FIFO |
| axis_source | AXI-Stream output |

### 4.2 Data Path

The data path flows left-to-right:

```
AXI-Stream Input (sensor/camera)
    -> axis_sink (spatial crop)
    -> activation_buffer (20x ping-pong BRAM)
    -> systolic_array (20x8 DSP48E1 MACs)
    -> requantization_unit (INT32 -> INT8)
    -> activation_unit (ReLU/ReLU6/LeakyReLU/HardSwish)
    -> pooling_unit (MaxPool/AvgPool)
    -> bbox_decoder (YOLOv8 coordinate decode)
    -> threshold_filter (confidence gate)
    -> output_buffer (FIFO)
    -> axis_source
AXI-Stream Output
```

### 4.3 Control Plane

The NPU is configured via AXI4-Lite memory-mapped registers:
- Layer geometry: input channels, output channels, width, height, tiles
- Processing parameters: kernel size, stride, padding, activation mode, pool mode
- DMA addresses: weight base, activation base, output base
- Performance counters: cycle count, compute count, stall counts

---

## 5. Processing Element Architecture

Each Processing Element (PE) implements a 3-stage pipelined MAC:

- Stage 1: 18x18 multiply (sign-extended INT8 inputs to guarantee DSP48E1 mapping)
- Stage 2: 36-bit result truncation and sign-extension to INT32
- Stage 3: INT32 accumulation with partial sum from column above

Key design decision: both weight and activation inputs are sign-extended from 8 bits to 18 bits before multiplication. Vivado DSP inference threshold is 18x18 bits minimum. This guarantees that each PE maps to exactly one DSP48E1 primitive rather than LUT carry chains.

---

## 6. Memory Architecture

### 6.1 Weight Buffer

The weight buffer implements software-managed ping-pong double buffering:
- Bank 0 and Bank 1 each hold one tile of weights
- CSR bit csr_wgt_bank_sel selects which bank the DMA writes to
- The compute engine reads from the opposite bank
- This allows overlapping DMA weight load with compute

### 6.2 Activation Buffer

- 20 ping-pong buffers, one per array row
- Each buffer stores INT8 activations for the current pixel
- Written by axis_sink (AXI-Stream input)
- Read by systolic_array
- Buffer swap controlled by npu_controller

---

## 7. NPU Controller FSM

The main FSM has six states:

| State | Function |
|---|---|
| STATE_IDLE | Wait for csr_start |
| STATE_LOAD_WGT | Trigger DMA to load 160 bytes of weights |
| STATE_LOAD_ACT | Wait for activation stream to fill buffers |
| STATE_DRAIN | Enable systolic array; wait ARRAY_ROWS + ARRAY_COLS + 8 cycles |
| STATE_STORE_OUT | Trigger DMA to store output_buffer to DDR |
| STATE_DONE | Assert status_done, generate interrupt |

Cosine similarity mode bypasses STATE_LOAD_WGT (weights pre-loaded).

---

## 8. AXI Interface Specification

### AXI4-Lite Slave (S_AXI)

| Signal | Direction | Width | Description |
|---|---|---|---|
| s_axi_awaddr | Input | 32 | Write address |
| s_axi_awvalid | Input | 1 | Write address valid |
| s_axi_awready | Output | 1 | Write address ready |
| s_axi_wdata | Input | 32 | Write data |
| s_axi_wstrb | Input | 4 | Write byte strobe |
| s_axi_wvalid | Input | 1 | Write data valid |
| s_axi_wready | Output | 1 | Write data ready |
| s_axi_bresp | Output | 2 | Write response |
| s_axi_bvalid | Output | 1 | Write response valid |
| s_axi_bready | Input | 1 | Write response ready |
| s_axi_araddr | Input | 32 | Read address |
| s_axi_arvalid | Input | 1 | Read address valid |
| s_axi_arready | Output | 1 | Read address ready |
| s_axi_rdata | Output | 32 | Read data |
| s_axi_rresp | Output | 2 | Read response |
| s_axi_rvalid | Output | 1 | Read data valid |
| s_axi_rready | Input | 1 | Read data ready |

### AXI4-Full Master (M_AXI)

| Signal | Direction | Width | Description |
|---|---|---|---|
| m_axi_araddr | Output | 32 | Read address (weight base) |
| m_axi_arlen | Output | 8 | Burst length (transfer_size - 1) |
| m_axi_arvalid | Output | 1 | Read address valid |
| m_axi_arready | Input | 1 | Read address ready |
| m_axi_rdata | Input | 32 | Read data (weight bytes) |
| m_axi_rlast | Input | 1 | Last beat of burst |
| m_axi_rvalid | Input | 1 | Read data valid |
| m_axi_rready | Output | 1 | Read data ready |
| m_axi_awaddr | Output | 32 | Write address (output base) |
| m_axi_awlen | Output | 8 | Burst length |
| m_axi_wdata | Output | 32 | Write data |
| m_axi_wlast | Output | 1 | Last beat |
| m_axi_wvalid | Output | 1 | Write valid |
| m_axi_wready | Input | 1 | Write ready |

### AXI4-Stream Slave (S_AXIS)

| Signal | Direction | Width | Description |
|---|---|---|---|
| s_axis_tdata | Input | 32 | Input activation data (4 bytes = 4 channels) |
| s_axis_tvalid | Input | 1 | Input valid |
| s_axis_tready | Output | 1 | Input ready |
| s_axis_tlast | Input | 1 | Last beat of frame |

### AXI4-Stream Master (M_AXIS)

| Signal | Direction | Width | Description |
|---|---|---|---|
| m_axis_tdata | Output | 32 | Output data (4 bytes = 4 channels) |
| m_axis_tvalid | Output | 1 | Output valid |
| m_axis_tready | Input | 1 | Output ready |
| m_axis_tlast | Output | 1 | Last beat of output frame |

---

## 9. Clock and Reset

### Clock

| Domain | Signal | Frequency | Modules |
|---|---|---|---|
| clk_compute | Gated from aclk | 125 MHz | Systolic array, DW engine, requantization |
| clk_postproc | Gated from aclk | 125 MHz | Activation, pooling, threshold, bbox |
| clk_dma | Gated from aclk | 125 MHz | DMA controller |

All three clock domains are derived from the single input aclk via the tinynpu_icg clock gate cell. Clock gating reduces dynamic power during idle states.

### Reset

- Signal: aresetn (active-low synchronous reset)
- All registers initialize to zero on reset
- CSR provides soft reset (csr_soft_reset) independent of hardware reset

---

## 10. Post-Processing Pipeline

### Requantization

Converts INT32 accumulator output back to INT8 using the formula:
```
output = clamp((acc + bias) * M0 >> n_shift, -128, 127)
```
Parameters M0 (scale) and n_shift (shift) are per-channel and runtime-configurable via CSR.

### Activation Functions

Selectable via 3-bit csr_act_ext:
- 3b000: ReLU max(0, x)
- 3b001: Identity
- 3b010: ReLU6 min(max(0, x), 6)
- 3b011: Leaky ReLU (alpha = 1/8)
- 3b100: HardSwish (LUT-based)

### Pooling

2x2 spatial pooling with 2-bit mode select:
- 2b00: Bypass
- 2b01: MaxPool
- 2b10: AvgPool

### BBox Decoder (YOLOv8)

Decodes anchor-free bounding box offsets (l, t, r, b) to absolute coordinates:
```
cx = (grid_x + 0.5) * stride
cy = (grid_y + 0.5) * stride
x1 = cx - l * stride
y1 = cy - t * stride
x2 = cx + r * stride
y2 = cy + b * stride
```
Confidence scores are decoded using piecewise_sigmoid approximation.

---

## 11. Verification

See VERIFICATION.md for full test case documentation.

**Summary:**
- 5 test cases implemented in tb_tinynpu_top.sv (SystemVerilog)
- Simulator: Vivado XSim behavioral
- Result: 5/5 PASS

---

## 12. Synthesis Target

| Item | Value |
|---|---|
| Target Part | xc7z020clg400-1 |
| Target Board | PYNQ-Z2 |
| Vivado Version | 2025.1 |
| Design Type | IP Core |
| RTL Style | Behavioral Verilog-2001 |

Note: Full synthesis resource utilization and timing closure results are pending and will be added in a future update.

---

## 13. Dual Operating Modes

| Mode | csr_cosine_sim_mode | Description |
|---|---|---|
| CNN Inference | 0 | Standard convolutional layer inference |
| Cosine Similarity | 1 | Face embedding comparison; skips weight DMA load |

---

## 14. Limitations

- Weight data width: DMA controller extracts only the lowest byte (bits [7:0]) of each 32-bit AXI read beat. Full 32-bit weight values require DMA controller modification.
- Single clock domain: All three gated clocks derive from the same source (no CDC handling needed but also no frequency scaling)
- BBox decoder: Channels 0-12 are processed by bbox_decoder; raw MAC results accessible on channels 13-19
- AXI burst: Maximum burst length limited to 256 beats (8-bit arlen)

---

## 15. Future Work

- NPU300PM variant: 20x8 array (160 PEs) for higher throughput
- RISC-V + NPU integrated SoC design
- Python/PYNQ driver for PS-side control
- Hardware demonstration results on PYNQ-Z2
- Power measurement and analysis
- Support for INT16 or mixed-precision inference
- On-chip weight storage for small models

---

## 16. References

1. Xilinx (AMD), "Zynq-7000 SoC Technical Reference Manual," UG585
2. Xilinx (AMD), "AXI Reference Guide," UG1037
3. Xilinx (AMD), "Vivado Design Suite User Guide: IP Packaging," UG1118
4. Redmon, J. et al., "YOLOv8: You Only Look Once" (Ultralytics, 2023)
5. Jacob, B. et al., "Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference," CVPR 2018
6. Jouppi, N. et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit," ISCA 2017

---

*Copyright (c) 2026 Hariharan Ganesh. All rights reserved.*  
*Contact: hariharanganesh67@gmail.com*

---
