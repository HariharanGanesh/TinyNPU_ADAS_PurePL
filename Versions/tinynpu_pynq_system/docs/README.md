# TinyNPU — FPGA Neural Processing Unit
### A Custom AI Accelerator on Xilinx Zynq-7020 (PYNQ-Z2)

> **RTL Language:** Verilog-2001 | **Tool:** Vivado 2025.1 | **Clock:** 100 MHz | **Precision:** INT8
> **Final Timing:** WNS = +0.033 ns ? | **Bitstream:** Generated & Verified

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Directory Structure](#2-directory-structure)
3. [Our Custom RTL Modules](#3-our-custom-rtl-modules)
4. [Vivado IP Blocks Used and Why](#4-vivado-ip-blocks-used-and-why)
5. [System Block Diagram](#5-system-block-diagram)
6. [AXI Bus Architecture](#6-axi-bus-architecture)
7. [Clock Domain Architecture](#7-clock-domain-architecture)
8. [How to Build](#8-how-to-build)
9. [Key Results](#9-key-results)
10. [Timing Closure History](#10-timing-closure-history)

---

## 1. Project Overview

TinyNPU is a **fully custom neural network inference accelerator** built from scratch in Verilog RTL. It runs on the **programmable logic (PL)** fabric of the Zynq-7020 SoC, offloading the compute-heavy matrix multiplications from the ARM CPU onto dedicated hardware.

**What it does:**
- Accepts image activation data streamed over AXI4-Stream
- Performs INT8 convolution using a weight-stationary 8x8 systolic array
- Supports both **pointwise 1x1 convolution** (via systolic array) and **depthwise 3x3 convolution** (via dedicated DW engine)
- Applies ReLU, Sigmoid (LUT-based), Max-Pooling, and Threshold Filtering in hardware
- Outputs detection results (bounding boxes + confidence scores) via AXI4-Stream

**Why not just run it on the CPU?**
A 64x64 frame with 8 channels x 64 MACs at 100 MHz = 409 million MACs/second in hardware vs ~40 million in software. Hardware is ~10x faster with much lower power.

---

## 2. Directory Structure

```
D:/Final year project/
|
+-- rtl/                          <- All hand-written Verilog RTL
|   +-- top/                      <- tinynpu_top.v (master top)
|   +-- systolic_array/           <- 8x8 PE array
|   +-- pe/                       <- Processing element + bbox decoder
|   +-- dw_engine/                <- Depthwise 3x3 conv engine
|   +-- buffers/                  <- Activation, weight, output buffers
|   +-- axi/                      <- AXI-Lite slave, AXI-Stream sink/source
|   +-- dma/                      <- DMA controller
|   +-- quantization/             <- Requantization, threshold filter
|   +-- activation/               <- ReLU, sigmoid LUT, piecewise sigmoid
|   +-- pooling/                  <- 2x2 max pooling
|   +-- control/                  <- NPU controller FSM
|   +-- clocking/                 <- ICG, BUFGCE clock gate
|   +-- core/                     <- SRAM primitives, reset sync
|   +-- frontend/                 <- Frame generator, PL top, result capture
|   +-- wrappers/                 <- FPGA and ASIC wrapper
|
+-- vivado_system/
|   +-- tinynpu_pynq_system/      <- Vivado project
|       +-- *.runs/impl_1/
|           +-- tinynpu_system_bd_wrapper.bit  <- BITSTREAM HERE
|
+-- ip_repo/tinynpu/              <- Packaged custom IP for Block Design
+-- verif/                        <- Testbenches and simulation
+-- TinyNPU2050.bat               <- Double-click to open project in Vivado
+-- package_ip.tcl                <- Re-package custom IP script
+-- gen_patch_rebuild.tcl         <- Full rebuild script
+-- final_timing_summary_genfix.txt <- Timing report (WNS = +0.033 ns)
```

---

## 3. Our Custom RTL Modules (29 Files, All Hand-Written)

### Top Level
| File | Description |
|---|---|
| rtl/top/tinynpu_top.v | Master top module. Instantiates all 12 subsystems. Defines two clock domains. |
| rtl/wrappers/fpga/tinynpu_fpga_wrapper.v | FPGA-specific wrapper with BUFG instantiation |
| rtl/wrappers/asic/tinynpu_asic_wrapper.v | ASIC-portable wrapper for future chip tape-out |

### Compute Core
| File | Description |
|---|---|
| rtl/systolic_array/systolic_array.v | 8x8 weight-stationary systolic array. 64 PEs, each 8-bit multiply. Same architecture as Google TPU v1. |
| rtl/pe/processing_element.v | Single PE. 2-stage pipelined MAC (multiply then accumulate). The 2-stage split was needed for 100 MHz timing. |
| rtl/dw_engine/dw_line_buffer.v | Depthwise 3x3 convolution engine. 2-row line buffer for sliding windows. 8 channels x 9 MACs per pixel. |

### Memory & Buffers
| File | Description |
|---|---|
| rtl/buffers/activation_buffer.v | Ping-pong double buffer. Systolic array reads Bank 0 while DMA writes Bank 1. Hides DMA latency. |
| rtl/buffers/weight_buffer.v | Dual-bank weight SRAM. Preloads next layer weights while computing current layer. |
| rtl/buffers/output_buffer.v | FIFO that holds output detections until the ARM reads them. |
| rtl/core/sram_1rw.v | Single-port SRAM primitive. Maps to BRAM on FPGA, standard cell SRAM on ASIC. |
| rtl/core/sram_2rw.v | True dual-port SRAM. Port A writes, Port B reads simultaneously. No arbitration. |

### Post-Processing Pipeline
| File | Description |
|---|---|
| rtl/quantization/requantization_unit.v | 3-stage INT8 requantizer. Scales 32-bit accumulator back to INT8 via multiply + shift + saturate. |
| rtl/activation/activation_unit.v | ReLU6 and PReLU activation functions. Fully combinational. |
| rtl/activation/sigmoid_lut.v | 256-entry BRAM LUT for sigmoid. 2-cycle latency. Used for YOLOv8 confidence scores. |
| rtl/activation/piecewise_sigmoid.v | 5-segment piecewise sigmoid. Combinational, zero BRAM. ASIC fallback. |
| rtl/pooling/pooling_unit.v | 2x2 Max Pooling. Reduces spatial resolution 2x. |
| rtl/pe/bbox_decoder.v | Decodes raw network output into (x, y, w, h, confidence) bounding box format. |
| rtl/quantization/threshold_filter.v | Hardware NMS gate. Passes detection only if confidence >= threshold. On clk_postproc domain. |

### AXI Interfaces
| File | Description |
|---|---|
| rtl/axi/axi4_lite_slave.v | 32-bit config register file. ARM writes start, layer type, image size, threshold before inference. |
| rtl/axi/axis_sink.v | AXI4-Stream input. Receives pixel stream from AXI DMA, writes to activation buffer. Handles backpressure. |
| rtl/axi/axis_source.v | AXI4-Stream output. Sends detection results to ARM over DMA. |
| rtl/dma/dma_controller.v | AXI4 master DMA. Fetches weight matrices from DDR3 into weight buffer. Fully autonomous. |

### Control & Clocking
| File | Description |
|---|---|
| rtl/control/npu_controller.v | Main FSM. States: IDLE -> LOAD_WEIGHTS -> COMPUTE -> DRAIN -> DONE. |
| rtl/core/tinynpu_icg.v | Integrated Clock Gate (ICG). Latch-based, glitch-free. Stops clk_postproc when idle to save power. |
| rtl/clocking/clk_gate_bufgce.v | FPGA-optimized clock gate using Xilinx BUFGCE primitive. |
| rtl/core/rst_sync.v | 2-FF asynchronous reset synchronizer. Prevents metastability on reset de-assertion. |

### Frontend & Utilities
| File | Description |
|---|---|
| rtl/frontend/frame_gen.v | Synthetic pixel stream generator for hardware self-test. Pipelined for timing closure. |
| rtl/frontend/pl_top.v | PL-side top-level wrapper. |
| rtl/frontend/result_capture.v | Captures output register values for debug readback via AXI-Lite. |

---

## 4. Vivado IP Blocks Used and Why

The Vivado Block Design connects our custom IP to standard Xilinx IP blocks.

### processing_system7 (PS7)
**VLNV:** xilinx.com:ip:processing_system7:5.5

The ARM Cortex-A9 dual-core processor hardwired inside the Zynq-7020 chip. Required in every Zynq Block Design.

**Why:** Provides the 100 MHz FCLKCLK[0] clock for all PL logic. Provides DDR3 memory access (weight matrices stored in DDR, fetched by our DMA). Provides AXI master/slave ports for control and data.

Configuration: FCLKCLK[0] = 100 MHz, GP0 AXI master for config, HP0 for weight DMA, HP2 for activation DMA.

---

### axi_dma
**VLNV:** xilinx.com:ip:axi_dma:7.1

Direct Memory Access engine. Reads data from DDR and pushes it as AXI4-Stream, or takes AXI4-Stream and writes to DDR without CPU involvement.

**Why:** Without DMA, the CPU would copy activation data byte-by-byte which is 100x slower. The DMA handles:
- MM2S (Memory-to-Stream): DDR -> Stream -> our axis_sink -> activation buffer
- S2MM (Stream-to-Memory): our axis_source -> Stream -> DDR for CPU to read results

---

### tinynpu100 (Our Custom IP)
**VLNV:** xilinx.com:user:tinynpu100:1.0

Our entire TinyNPU accelerator (all 29 Verilog modules) packaged as a Vivado IP core.

**Why packaged as IP:** Vivado Block Designer only understands IP cores with defined AXI interfaces. Packaging with ipx::package_project makes Vivado auto-detect our AXI ports and create proper connections.

---

### smartconnect
**VLNV:** xilinx.com:ip:smartconnect:1.0

Intelligent AXI bus fabric. Routes transactions between multiple masters and slaves.

**Why:** We have the CPU and our DMA both needing DDR access simultaneously. SmartConnect handles address decoding, protocol conversion (AXI3 <-> AXI4), and data width conversion. It allows both DMAs to run concurrently without blocking each other.

---

### proc_sys_reset
**VLNV:** xilinx.com:ip:proc_sys_reset:5.0

Synchronous reset manager. Converts the raw PS power-on reset into clean synchronized active-low reset for all PL modules.

**Why:** Raw async resets cause metastability across the PL (different FFs come out of reset at different clock edges). proc_sys_reset holds reset for a fixed number of clock cycles and synchronizes de-assertion to the 100 MHz clock.

---

### axi_interconnect
**VLNV:** xilinx.com:ip:axi_interconnect:2.1

AXI bus switch for the control path (CPU -> peripheral config registers).

**Why:** Routes the single CPU GP0 AXI-Lite master to both our NPU config slave and the AXI DMA config slave, with address decoding.

---

### axi_crossbar (inside SmartConnect)
**VLNV:** xilinx.com:ip:axi_crossbar:2.1

Non-blocking AXI crossbar that allows multiple masters to access multiple slaves simultaneously.

**Why:** Auto-generated inside SmartConnect. Allows our weight-fetch DMA and activation DMA to access DDR simultaneously at full bandwidth without serialization.

---

### axi_protocol_converter (inside SmartConnect)
**VLNV:** xilinx.com:ip:axi_protocol_converter:2.1

Converts between AXI3 (Zynq PS ports) and AXI4 (our DMA) protocol versions.

**Why:** The Zynq HP slave ports use AXI3 (16-beat burst max). Our DMA uses AXI4 (256-beat burst). Without this converter they are incompatible. Auto-inserted by SmartConnect.

---

### axi_dwidth_converter (inside SmartConnect)
**VLNV:** xilinx.com:ip:axi_dwidth_converter:2.1

Converts between AXI data bus widths (e.g. 32-bit to 64-bit).

**Why:** Our m_axi weight DMA is 32-bit (weight data packed as 8-bit x 4). The PS HP0 slave is 64-bit (optimized for DDR3). The converter packs two 32-bit words into one 64-bit DDR transaction, doubling effective weight-fetch bandwidth.

---

## 5. System Block Diagram

```
+------------------------------------------------------------------+
|                    Zynq-7020 PS (ARM)                            |
|  GP0 AXI Mstr    HP0 AXI Slv     HP2 AXI Slv     DDR3 Memory   |
+----+----------------+------------------+----------------+--------+
     |                |                  |                |
     |       +---------+                 |                |
     |       | (weight DMA)              |                |
+----v-------v----------+   +-----------v----------------v--------+
|  AXI SmartConnect     |   |        AXI DMA (7.1)               |
|  (Crossbar + Protocol |   |  MM2S: DDR->Stream (activations)   |
|   + Width Converters) |   |  S2MM: Stream->DDR (results)       |
+-----------+-----------+   +--------+------------------+--------+
            |                        | AXI-Stream        | AXI-Stream
            | rst_n                  |                   |
+-----------v------------------------v-------------------v--------+
|              tinynpu100 Custom IP                              |
|  axis_sink -> activation_buffer -> systolic_array (8x8)       |
|  dma_ctrl  -> weight_buffer     -> dw_line_buffer (3x3)       |
|  axi4_lite_slave (CSR config)   -> npu_controller FSM         |
|                                                                |
|  output -> requant -> activation -> pooling                   |
|         -> bbox_decoder -> threshold_filter                   |
|         -> output_buffer -> axis_source                       |
+----------------------------------------------------------------+
```

---

## 6. AXI Bus Architecture

| Bus | Protocol | Width | Master | Slave | Purpose |
|---|---|---|---|---|---|
| GP0 -> AXI Interconnect | AXI4-Lite | 32-bit | PS ARM | NPU Config + DMA Config | CPU writes config registers |
| NPU m_axi -> SmartConnect -> HP0 | AXI4 (conv to AXI3) | 32->64-bit | TinyNPU DMA | PS HP0 -> DDR | Weight matrix fetch |
| AXI DMA -> HP2 | AXI4->AXI3 | 64-bit | AXI DMA | PS HP2 -> DDR | Activation data DMA |
| AXI DMA -> axis_sink | AXI4-Stream | 32-bit | AXI DMA | TinyNPU | Stream input activations |
| axis_source -> AXI DMA | AXI4-Stream | 32-bit | TinyNPU | AXI DMA | Stream output results |

---

## 7. Clock Domain Architecture

```
PS FCLKCLK[0] (100 MHz)
    |
    v
BUFGCTRL_X0Y16 (main BUFG)
    |
    +---------------------------------- clk domain (always on)
    |   Clocks: AXI, DMA, CSR, npu_controller, systolic_array
    |
    +-> tinynpu_icg -> BUFGCTRL_X0Y19 -- clk_postproc (gated)
             |
         Enable when:   Clocks: activation_unit, pooling_unit,
         requant_valid   threshold_filter, requantization_unit
         OR pool_enable
```

Why two clock domains? When the systolic array is loading weights, the post-processing pipeline is idle. Gating its clock saves ~15-20% dynamic power.

CRITICAL: Both u_pooling and u_threshold_filter MUST be on clk_postproc (same BUFG). If threshold_filter is on the ungated clk, a -3.35 ns clock skew violation appears. This was the main timing closure challenge solved in this project.

---

## 8. How to Build

### Open Project (easiest)
Double-click: D:\Final year project\TinyNPU2050.bat

### Full Rebuild from Script
```
cd "D:\Final year project"
vivado.bat -mode batch -source gen_patch_rebuild.tcl -log rebuild.log -nojournal
```

### Re-package Custom IP (after RTL changes)
```
vivado.bat -mode batch -source package_ip.tcl -nojournal
```

IMPORTANT: After any RTL change to rtl/top/tinynpu_top.v, you must also apply the same change to:
vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.gen/sources_1/bd/tinynpu_system_bd/ipshared/bd96/src/tinynpu_top.v
Because Vivado caches IP synthesis and ignores ip_repo changes unless the .gen file is updated directly.

### Bitstream Location
```
D:\Final year project\vivado_system\tinynpu_pynq_system\tinynpu_pynq_system.runs\impl_1\tinynpu_system_bd_wrapper.bit
```

---

## 9. Key Results

| Metric | Value |
|---|---|
| Clock Frequency | 100 MHz |
| WNS (Worst Negative Slack) | +0.033 ns (timing met) |
| TNS (Total Negative Slack) | 0.000 ns (zero violations) |
| Total Timing Endpoints Checked | 61,874 |
| DRC Errors | 0 |
| Hand-written RTL Files | 29 Verilog modules |
| Peak Throughput | ~6.4 GMAC/s (64 MACs x 100 MHz) |
| Precision | INT8 |
| Bitstream | Generated and verified |
| ASIC Portable | Yes - Verilog-2001, no Xilinx primitives in compute core |

---

## 10. Timing Closure History

| Build | WNS | Problem | Fix |
|---|---|---|---|
| Initial | -1.285 ns | frame_gen.v: 11 LUT levels in one comparison path | Pipelined comparison into 2 register stages |
| After RTL fix | -0.602 ns | Post-route placement suboptimal | Ran AggressiveExplore post-route phys_opt |
| After phys_opt | -0.539 ns | Clock domain skew discovered | Investigated ICG BUFG insertion delay |
| After clock fix | -0.176 ns | u_pooling on ICG BUFG (SCD=6.217ns) vs u_threshold_filter on direct BUFG (SCD=2.751ns) = -3.35ns skew | Changed threshold_filter to clk_postproc |
| Cache-bust attempts | -0.176 ns | Vivado served old DCP from .gen/ cache, not ip_repo | Direct patch to .gen/ipshared/bd96/src/tinynpu_top.v |
| FINAL | +0.033 ns | Done | Success |

---

*TinyNPU - Built with Verilog-2001. ASIC-portable. 100 MHz verified.*

---

## 11. Difficulties Faced and Fixes Applied

This section documents every major problem we ran into and exactly how we solved it.
Useful for anyone who continues this project or faces similar issues with Vivado.

---

### Problem 1: Timing Violation in frame_gen.v (-1.285 ns WNS)

**What happened:**
The very first implementation failed timing with WNS = -1.285 ns.
The Vivado timing report pointed to the frame_gen module as the critical path.
The module compared a multi-bit counter against a constant value in a single always block.
Vivado synthesis created 11 LUT levels in series to evaluate this comparison, which took ~12.8 ns - way over the 10 ns budget.

**Root cause:**
Single-cycle combinational comparison of a wide bus. When you write:
```
if (pixel_count == TOTAL_PIXELS - 1)
```
Vivado builds a tree of LUTs to evaluate all bits in one shot.
For a wide counter, this tree can be 8-11 levels deep, each level adding ~0.15-0.5 ns.

**Fix applied:**
We pipelined the comparison across two clock cycles:
- Stage 1 (Cycle N): Register intermediate comparison results
- Stage 2 (Cycle N+1): Register the final decision

This broke the 11-level LUT chain into two ~5-level chains, each taking ~5.5 ns.
Both stages now comfortably fit within one 10 ns clock period.

**File changed:** rtl/frontend/frame_gen.v (lines 67-80)

**WNS improvement:** -1.285 ns -> -0.602 ns

---

### Problem 2: Clock Domain Skew Violation (-0.176 ns WNS)

**What happened:**
After the frame_gen fix and a round of post-route physical optimization (phys_opt_design),
WNS improved from -0.602 ns to -0.176 ns. The critical path shifted to a path between
u_pooling (source register) and u_threshold_filter (destination register).

The timing report showed:
- Source Clock Delay (SCD) = 6.217 ns (u_pooling clock arrives late)
- Destination Clock Delay (DCD) = 2.751 ns (u_threshold_filter clock arrives early)
- Clock Path Skew = DCD - SCD + CPR = -3.351 ns

This -3.351 ns skew was the entire problem. With 10 ns clock period and 6.748 ns data path,
the effective setup budget was only 10 - 3.351 - 0.154 (jitter) = 6.495 ns.
The data path needed 6.748 ns, so it failed by 0.176 ns.

**Root cause (the ICG BUFG problem):**
The design uses an Integrated Clock Gate (tinynpu_icg.v) to generate clk_postproc
from the main clk. When Vivado synthesizes a latch-based clock gate, it inserts an
extra BUFG (BUFGCTRL_X0Y19) for the gated clock output.

This extra BUFG adds ~3.5 ns of insertion delay to clk_postproc compared to the
ungated clk. So:
- u_pooling was on clk_postproc (through the ICG BUFG) -> SCD = 6.217 ns
- u_threshold_filter was on clk (direct BUFG, no ICG) -> SCD = 2.751 ns

Same logical clock, but 3.5 ns difference in physical insertion delay = timing violation.

**Fix applied:**
Changed u_threshold_filter to use clk_postproc instead of clk.
Now both source (u_pooling) and destination (u_threshold_filter) go through the
same ICG BUFG (BUFGCTRL_X0Y19), so their clock insertion delays are equal.
Clock skew dropped from -3.351 ns to approximately 0 ns, adding ~+3.2 ns of slack.

**File changed:** tinynpu_top.v, line 772:
```
Before: .clk(clk),        <- wrong: direct BUFG, SCD = 2.751 ns
After:  .clk(clk_postproc), <- correct: same ICG BUFG as u_pooling, SCD = 6.2 ns
```

**WNS improvement:** -0.176 ns -> +0.033 ns (CLOSED)

---

### Problem 3: Vivado IP Synthesis Cache Refusing to Pick Up RTL Changes

**What happened:**
We made the clock fix in rtl/top/tinynpu_top.v and also in ip_repo/tinynpu/src/tinynpu_top.v.
We ran multiple rebuilds. WNS stayed at -0.176 ns every single time.
The timing report still showed u_threshold_filter on the wrong clock (clk_fpga_0 directly).

This was extremely frustrating. The fix was clearly in the source file, but the netlist
kept showing the old behavior.

**Root cause (Vivado IP caching system):**
Vivado uses a multi-level caching system for IP synthesis:
1. ip_repo/ (our source) -> used by package_ip.tcl to create the IP
2. ip_repo is imported into: .gen/sources_1/bd/tinynpu_system_bd/ipshared/bd96/src/
3. The sub-synthesis run (tinynpu_system_bd_tinynpu100_0_0_synth_1) compiles the .gen file
4. The result is cached as a DCP in .runs/tinynpu_system_bd_tinynpu100_0_0_synth_1/
5. The top-level synth_1 and impl_1 use this cached DCP

When we changed ip_repo, Vivado updated step 1 but NOT steps 2-4 automatically.
The .gen file (step 2) still had the old .clk(clk) code.
Even after reset_run and config_ip_cache -disable_cache, the .gen file was never overwritten.

**Things we tried that did NOT work:**
- reset_run tinynpu_system_bd_tinynpu100_0_0_synth_1 -> still used cached DCP
- config_ip_cache -disable_cache + reset_run -> .gen file unchanged, still compiled old code
- Deleting IP cache directories (.cache/ip/2025.1/*) -> Vivado regenerated from .gen (still old)
- Bumping IP version to 2.1 and upgrade_ip -> WARNING: No IP was identified for upgrade
- All phys_opt_design directives (AggressiveExplore, AggressiveFanoutOpt, AlternateReplication)
  -> Zero improvement. PhysOpt cannot change which BUFG a register is clocked by.

**Fix that worked:**
Directly edit the .gen file that Vivado actually reads for synthesis:
```
D:\Final year project\vivado_system\tinynpu_pynq_system\
  tinynpu_pynq_system.gen\sources_1\bd\tinynpu_system_bd\
  ipshared\bd96\src\tinynpu_top.v
```
Changed line 772 from .clk(clk) to .clk(clk_postproc) directly in this file.
Then deleted the stale sub-synthesis run directory:
```
.runs\tinynpu_system_bd_tinynpu100_0_0_synth_1\
```
This forced Vivado to re-synthesize tinynpu100 from scratch using the patched .gen file.

**IMPORTANT NOTE FOR THE TEAM:**
The .gen directory file is the AUTHORITATIVE source for Vivado synthesis.
Changes to ip_repo/ alone are NOT enough. You must update BOTH:
1. rtl/top/tinynpu_top.v (the human-readable source)
2. .gen/ipshared/bd96/src/tinynpu_top.v (what Vivado actually compiles)

---

### Problem 4: Deleting Wrong Directories Caused Build Failures

**What happened:**
In early attempts to force re-synthesis, we tried deleting the IP directory to force
regeneration. This caused synthesis errors like "file not found" because Vivado
expected generated wrapper .v files to exist in the .gen directory.

**Root cause:**
The Vivado Block Design flow has two separate directory trees:
- .gen/sources_1/bd/.../ip/tinynpu_system_bd_tinynpu100_0_0/
  Contains: generated AXI wrapper .v files (do NOT delete this)
- .runs/tinynpu_system_bd_tinynpu100_0_0_synth_1/
  Contains: synthesis DCP cache (safe to delete to force re-synthesis)

**Fix applied:**
Only delete the .runs synthesis directory, never the .gen sources directory.
The synthesis run uses the .gen files as input - those must exist.

---

### Problem 5: ICG Latch Warning in Timing Report

**What happened:**
The final timing summary shows:
- LATCH-1 Advisory: Existing latches in the design = 1
- TIMING-14 Critical Warning: LUT on the clock tree = 3

**Root cause:**
The tinynpu_icg.v module is a latch-based clock gate (industry-standard ASIC pattern).
It deliberately uses a level-sensitive latch to hold the clock enable signal,
then ANDs it with the clock to produce a glitch-free gated output.
Vivado flags this because latches are unusual in synchronous FPGA designs.

**Why we accepted it:**
This is a known, intentional design choice. The ICG is a standard cell in every ASIC library.
On FPGA, Vivado maps it to a BUFGCE (BUFG with clock enable) which handles the glitch-free
gating natively. The latch warning is cosmetic - the design is functionally correct.

The 3 LUT-on-clock-tree warnings are also from the ICG enable logic (the LUT2 that feeds
the BUFG enable pin). This is expected and harmless.

---

### Problem 6: DRC Warning About AXI DMA XPM Memory Type

**What happened:**
During write_bitstream, Vivado reported:
"Found XPM memory block with P_MEMORY_PRIMITIVE set to auto. A value of block is required."

**Root cause:**
The AXI DMA IP internally uses an XPM (Xilinx Parameterized Macro) FIFO with
P_MEMORY_PRIMITIVE = auto. Vivado's DRC check warns that 'auto' prevents the
updatemem tool from patching the memory contents post-synthesis.

**Why we accepted it:**
This is inside Xilinx's own AXI DMA IP - we cannot change it.
The warning does NOT affect functionality. The FIFO works correctly at runtime.
It only means we cannot use the 'updatemem' utility to patch this FIFO's contents
in the bitstream after synthesis - which we never need to do.

The bitstream was generated successfully with 0 errors despite this warning.

---

### Problem 7: Board Part Warning on Project Open

**What happened:**
Every time the project opens in Vivado, dozens of warnings appear:
"cannot add Board Part xilinx.com:vpk180:part0:1.0 ... part xcvp1802 not available"

**Root cause:**
Vivado 2025.1 ships with board definition files for many boards including the VPK180,
VMK180, ZCU208, etc. These boards require specific silicon parts that are not installed
in our Vivado license/installation. The board store tries to load all board definitions
and fails silently for boards whose parts are not present.

**Why we accepted it:**
These are warnings only, not errors. Our target board (PYNQ-Z2 with xc7z020clg400-1)
is correctly recognized and all project settings are correct. The other board warnings
are irrelevant to our project and can be ignored.

---

## Summary of All Problems and Fixes

| # | Problem | WNS Impact | Fix | Time Cost |
|---|---|---|---|---|
| 1 | frame_gen.v: 11-LUT comparison path | -1.285 ns | Pipeline comparison into 2 stages | 1 hour |
| 2 | ICG clock skew: threshold_filter on wrong clock | -0.176 ns | Change .clk(clk) to .clk(clk_postproc) | 2 hours |
| 3 | Vivado IP cache not picking up RTL change | Stuck at -0.176 ns | Direct patch to .gen/ipshared/bd96/src/ | 6 hours debugging |
| 4 | Deleting wrong directory caused build failure | Build error | Only delete .runs/ not .gen/ | 30 minutes |
| 5 | ICG latch warning | Advisory only | Accepted - intentional ASIC pattern | None |
| 6 | AXI DMA XPM memory warning | None - cosmetic | Accepted - inside Xilinx IP | None |
| 7 | Board part warnings on open | None - cosmetic | Accepted - wrong board files | None |

**Final result after all fixes: WNS = +0.033 ns. Timing CLOSED. Bitstream verified.**
