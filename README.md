<div align="center">

# TinyNPU200A
### FPGA AI Accelerator · RISC-V ADAS · Pure PL Implementation

**A weight-stationary 2D Systolic Array NPU implemented entirely in synthesizable Verilog-2001,  
targeting the Xilinx Zynq-7020 (PYNQ-Z2) as a 100% Programmable Logic design.**

---

[![Platform](https://img.shields.io/badge/Platform-PYNQ--Z2%20%2F%20Zynq--7020-orange?style=flat-square)](https://www.xilinx.com)
[![Tool](https://img.shields.io/badge/Vivado-2025.1-blue?style=flat-square)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Language](https://img.shields.io/badge/RTL-Verilog--2001-green?style=flat-square)](#)
[![Interface](https://img.shields.io/badge/Interface-AXI4--Lite%20%7C%20AXI4--Stream-blueviolet?style=flat-square)](#)
[![Verification](https://img.shields.io/badge/Verification-SystemVerilog%20%7C%20POV%20PASS-brightgreen?style=flat-square)](#verification)
[![License](https://img.shields.io/badge/License-Proprietary%20IP-red?style=flat-square)](TERMS_OF_USE.md)

[Architecture](#-architecture) · [Results](#-implementation-results) · [Build](#-how-to-build) · [Verification](#-verification) · [Docs](#-documentation) · [Contact](#-contact)

</div>

---

## Overview

**TinyNPU200A** is a fully custom, hand-written RTL Neural Processing Unit (NPU) IP core, built as a pure Programmable Logic (PL) design with no ARM PS dependency. It accelerates INT8 quantized neural network inference (YOLOv8-style) in real-time on the PYNQ-Z2 board by coupling a 2D Systolic Array MAC engine with a complete ADAS detection pipeline — including Top-K extraction, Distributed Focal Loss (DFL) bounding box decoding, and a Sparse Candidate Packer — all in hardware.

The design integrates an HDMI video input/output pipeline at 200 MHz alongside the NPU compute fabric running at 125 MHz, with a RISC-V soft-core for configuration and control. Every module is synthesizable Verilog-2001 and has been functionally verified.

---

## Architecture

```
+---------------------------------------------------------------------+
¦                         PYNQ-Z2 PL Fabric                           ¦
¦                                                                     ¦
¦  HDMI In          +--------------+      +-------------------------+¦
¦  (DVI2RGB)  ---?  ¦  AXI4-Stream ¦ ---? ¦   TinyNPU200 Core       ¦¦
¦                   ¦  Video Sink  ¦      ¦   20×8 Systolic Array   ¦¦
¦                   +--------------+      ¦   INT8 · Weight-Static  ¦¦
¦                                         +-------------------------+¦
¦  HDMI Out         +--------------+                   ¦              ¦
¦  (RGB2DVI)  ?---  ¦  AXI4-Stream ¦      +------------?------------+¦
¦                   ¦  Video Src   ¦      ¦   ADAS Detection Head   ¦¦
¦                   +--------------+      ¦   Top-K · DFL · Packer  ¦¦
¦                                         +-------------------------+¦
¦  AXI4-Lite CSRs ?------------------------------------+              ¦
¦  RISC-V Controller (Weights, Config, Status)                        ¦
¦                                                                     ¦
+---------------------------------------------------------------------+
```

### Core Modules

| Module | Description |
|---|---|
| `tinynpu_top.v` | Top-level NPU wrapper integrating systolic array, buffers, and AXI interfaces |
| `systolic_array.v` | 20×8 grid of MAC Processing Elements, weight-stationary dataflow |
| `weight_buffer.v` | BRAM-backed weight storage with AXI4 DMA master interface |
| `activation_buffer.v` | Double-buffered BRAM for ping-pong tiling |
| `npu_detection_head.v` | Integrates Top-K, DFL decoder, and sparse packer for ADAS output |
| `streaming_topk.v` | Streaming hardware Top-K confidence extractor |
| `bbox_decoder_dfl.v` | 4× parallel DFL bounding box decoder (17-bin histogram) |
| `sparse_candidate_packer.v` | 128-bit ADAS memory record assembler ? BRAM write |
| `sigmoid_lut.v` | BRAM-based 256-entry sigmoid activation LUT (2-cycle latency) |
| `npu_system.bd` | Vivado Block Design: NPU + HDMI PHYs + CLK Wizard + VTC + JTAG AXI |

---

## Implementation Results

> Targeting: **Xilinx Zynq-7020 (xc7z020clg400-1)** on the **PYNQ-Z2** board  
> Tool: **Vivado 2025.1** · Reports: [`Reports/`](Reports/)

### Resource Utilization

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 5,756 | 53,200 | **10.82 %** |
| Slice Registers | 9,379 | 106,400 | **8.81 %** |
| Block RAM Tiles | 3 | 140 | **2.14 %** |
| DSP48E1 | 0 | 220 | **0.00 %** |
| Bonded IOB | 24 | 125 | **19.20 %** |

### Timing

| Clock Domain | Frequency | Status |
|---|---|---|
| NPU Datapath | **125 MHz** | ? Timing Met |
| HDMI Video PHY | **200 MHz** | ? Timing Met |

### Implementation Notes
- **30,572 internal nets** fully routed · **0 overlaps**
- Bitstream generated: `npu_system_wrapper.bit` (~4 MB)
- Flashed via Vivado Hardware Manager (JTAG) — no Vitis, no BOOT.bin required

---

## Verification

The ADAS detection pipeline has been verified end-to-end via SystemVerilog testbenches. Summaries are in [`verification/reports/summaries/`](verification/reports/summaries/).

### Test Results

| Test Case | Module Under Test | Status |
|---|---|---|
| POV 01 — Functional | `streaming_topk` | ? PASS |
| POV 03 — Corner Case | `bbox_decoder_dfl` | ? PASS |
| POV 04 — Reset Behaviour | `sparse_candidate_packer` | ? PASS |
| POV 10 — Integration | `npu_detection_head` (full pipeline) | ? PASS |

### Integration Test Detail (POV 10)

```
Input:  200 parallel INT8 class logits + 4× 17-bin DFL distributions
Output: 128-bit ADAS memory record via BRAM write

Captured: 004d0063002800140016000b00010000
Decoded:
  [127:112]  Class ID  = 77   ? MATCH
  [111:96]   Score     = 99   ? MATCH
  [95:80]    Y2        = 40   ? MATCH
  [79:64]    X2        = 20   ? MATCH
  [63:48]    Y1        = 22   ? MATCH
  [47:32]    X1        = 11   ? MATCH
  [31:16]    Scale     = 1    ? MATCH
  [15:0]     Flags     = 0    ? MATCH

Result: PASS — 0 bugs in integration path
```

---

## Repository Structure

```
TinyNPU_ADAS_PurePL/
¦
+-- IP/                             # Custom IP cores (Verilog RTL)
¦   +-- TinyNPU200/                 #   NPU datapath: systolic array, buffers, AXI
¦   +-- NPU300PM/                   #   Next-gen NPU variant (in development)
¦   +-- RISCV_ADAS_Controller/      #   RISC-V soft-core for NPU/ADAS control
¦
+-- RISCV_ADAS_PURE_PL/             # Vivado 2025.1 project (open this .xpr)
¦   +-- RISCV_ADAS_PURE_PL.xpr     #   Block design, IP configs, impl runs
¦
+-- verification/                   # SystemVerilog verification suite
¦   +-- tb/                         #   Testbenches (.sv)
¦   +-- tests/                      #   Directed test environments
¦   +-- reports/summaries/          #   Human-readable verification reports
¦   +-- reports/bugs/               #   Bug reports and fix log
¦
+-- constraints/                    # Physical XDC constraint files
¦   +-- pynq_z2_customized.xdc      #   Primary PYNQ-Z2 pin assignment
¦   +-- pynq_z2_adas.xdc            #   ADAS GPIO mappings (LEDs/Switches)
¦   +-- hdmi_video_pins.xdc         #   HDMI PHY pin mapping
¦   +-- tinynpu_master.xdc          #   Master timing constraints
¦   +-- ooc_timing.xdc              #   Out-of-context synthesis target (100 MHz)
¦   +-- timing_fix.xdc              #   Timing override patches
¦   +-- clock_bypass.xdc            #   BUFG-BUFG cascade bypass
¦   +-- drc_bypass.xdc              #   Digilent DVI2RGB OOC DRC waiver
¦
+-- firmware/                       # Baremetal RISC-V firmware
¦   +-- riscv_firmware_main.c       #   Main NPU control & ADAS loop
¦   +-- dummy_data.h                #   Verification data headers
¦
+-- docs/                           # Technical documentation
¦   +-- TinyNPU200_IEEE_Spec.md     #   IP core specification
¦   +-- PROJECT_REPORT.md           #   Full technical project report
¦   +-- USER_MANUAL.md              #   IP integration & usage guide
¦   +-- VERIFICATION.md             #   Verification methodology
¦   +-- ml_model_hardware_spec.md   #   YOLOv8 INT8 ? hardware mapping
¦   +-- fpga_testing_guide.md       #   JTAG flashing & hardware testing guide
¦   +-- project_workflow_guide.md   #   Development workflow reference
¦   +-- pynq_z2_dummy_test_guide.md #   Dummy test procedure for board bring-up
¦
+-- Reports/                        # Vivado-generated implementation reports
¦   +-- RISCV_ADAS_PURE_PL_Timing.rpt
¦   +-- RISCV_ADAS_Utilization.rpt
¦
+-- scripts/                        # Setup & automation scripts
¦   +-- install_riscv_gcc.ps1       #   RISC-V GCC toolchain installer (Windows)
¦
+-- Project_Documents/              # Academic documents, posters, presentations
¦
+-- .gitignore                      # Excludes Vivado build artifacts
+-- README.md                       # This file
+-- CHANGELOG.md                    # Version history
+-- CONTRIBUTING.md                 # Contribution guidelines
+-- ACCESS.md                       # IP access request process
+-- TERMS_OF_USE.md                 # Copyright & usage terms
```

---

## How to Build

### 1 — Clone

```bash
git clone https://github.com/HariharanGanesh/TinyNPU_ADAS_PurePL.git
cd TinyNPU_ADAS_PurePL
```

### 2 — Open Vivado Project

```
File ? Open Project ? RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
```

### 3 — Generate Bitstream

In Vivado, click **Generate Bitstream**, or in the Tcl Console:

```tcl
launch_runs impl_1 -to_step write_bitstream -jobs 4
```

### 4 — Flash to PYNQ-Z2 via JTAG

```
Open Hardware Manager ? Auto Connect ? Program Device
Select: RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.runs/impl_1/npu_system_wrapper.bit
```

> **Note:** This is a pure PL design. No Vitis, no BOOT.bin, and no ARM PS required.

---

## Documentation

| Document | Description |
|---|---|
| [TinyNPU200 IP Spec](docs/TinyNPU200_IEEE_Spec.md) | Architecture, parameters, interfaces, and known behaviours |
| [Project Report](docs/PROJECT_REPORT.md) | Full technical report: motivation, design decisions, results |
| [User Manual](docs/USER_MANUAL.md) | How to import the IP, configure parameters, and integrate in Block Design |
| [Verification Report](docs/VERIFICATION.md) | Testbench methodology, test cases, and results |
| [ML Hardware Spec](docs/ml_model_hardware_spec.md) | YOLOv8n INT8 quantization ? hardware datapath mapping |
| [FPGA Testing Guide](docs/fpga_testing_guide.md) | Board bring-up, JTAG flashing, and hardware debug guide |

---

## Intellectual Property & Governance

This project is **proprietary intellectual property**.

> Public visibility of this repository does **not** grant any license to use, copy, modify, or redistribute the RTL or IP.

| Document | Purpose |
|---|---|
| [TERMS_OF_USE.md](TERMS_OF_USE.md) | Full copyright and usage restrictions |
| [ACCESS.md](ACCESS.md) | How to request IP access (academic / research / commercial) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Bug report and suggestion guidelines |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |

---

## Contact

**Hariharan Ganesh**  
Final Year Engineering Student · FPGA & VLSI Design  
?? [hariharanganesh67@gmail.com](mailto:hariharanganesh67@gmail.com)  
?? [github.com/HariharanGanesh](https://github.com/HariharanGanesh)

---

<div align="center">
<sub>Copyright (c) 2026 Hariharan Ganesh. All rights reserved.</sub>
</div>
