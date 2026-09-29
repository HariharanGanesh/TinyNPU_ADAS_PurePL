# User Manual ? TinyNPU200 IP Core

**Author:** Hariharan Ganesh  
**Email:** hariharanganesh67@gmail.com  
**Version:** 1.0  

> Copyright (c) 2026 Hariharan Ganesh. All rights reserved.  
> **Use of this IP requires written authorization. See ACCESS.md.**

---

## Table of Contents

1. Prerequisites
2. Repository Structure
3. Importing the IP into Vivado
4. Configuring Parameters
5. Interface Reference
6. CSR Register Map
7. Simulation Quick Start
8. Hardware Integration
9. Software Driver Overview
10. Troubleshooting

---

## 1. Prerequisites

### Software

| Requirement | Version | Notes |
|---|---|---|
| Vivado Design Suite | 2025.1 | Required for simulation and implementation |
| Python | 3.x (optional) | For PYNQ-based driver |
| Git | Any | For cloning the repository |

### Hardware (for FPGA implementation)

| Requirement | Details |
|---|---|
| FPGA Board | PYNQ-Z2 (Digilent) |
| FPGA Device | Xilinx xc7z020clg400-1 |
| Clock Source | 125 MHz from PS7 FCLK_CLK0 |
| AXI Interconnect | Required for S_AXI and M_AXI connections |
| AXI-Stream Source | Required for S_AXIS input |
| AXI-Stream Sink | Required for M_AXIS output |

### IP Dependencies

The TinyNPU200 IP has no external IP dependencies. All submodules are included
in the `IP/TinyNPU200/src/` directory as synthesizable RTL.

---

## 2. Repository Structure

```
TinyNPU200/
|-- IP/TinyNPU200/
|   |-- component.xml        <- Vivado IP descriptor
|   |-- src/                 <- All 21 RTL source files (.v)
|   `-- sim/
|       |-- tb_tinynpu_top.sv  <- SystemVerilog testbench
|       `-- dummy_weights.hex  <- Simulation weight file
|
|-- tinynpu200_ip_packager/
|   `-- tinynpu200_ip_packager.xpr  <- Vivado project
|
|-- docs/
|   |-- PROJECT_REPORT.md
|   |-- USER_MANUAL.md       <- This file
|   |-- VERIFICATION.md
|   `-- IP_INTEGRATION.md
|
|-- run_all.tcl              <- Simulation entry point
|-- run_simulation.bat       <- Windows one-click simulation
|-- scripts/
|   `-- run_simulation_portable.tcl  <- Path-independent sim script
|
|-- tinynpu_master.xdc       <- Constraints (PYNQ-Z2)
|-- ACCESS.md                <- IP access policy
|-- TERMS_OF_USE.md          <- Usage terms
`-- README.md                <- Project overview
```

---

## 3. Importing the IP into Vivado

### Method A: Add IP Repository

1. Open Vivado 2025.1
2. Open your Vivado project (or create a new one targeting xc7z020clg400-1)
3. Go to **Tools > Settings > IP > Repository**
4. Click **+** and navigate to the parent directory of `IP/TinyNPU200/`
   - Select the folder that *contains* the `TinyNPU200` folder (the one with component.xml)
5. Vivado detects `tinynpu_top v1.0`
6. Click OK

### Method B: Open Existing Simulation Project

For simulation only:
1. In Vivado, click **Open Project**
2. Navigate to `tinynpu200_ip_packager/tinynpu200_ip_packager.xpr`
3. This project already has all RTL files added and simulation configured

> **Note about paths:** The .xpr file uses relative paths ($PPRDIR/../IP/TinyNPU200/src/...),
> so the repository directory structure must be preserved. Do not move the
> tinynpu200_ip_packager/ directory relative to the IP/ directory.

---

## 4. Configuring Parameters

The IP parameters are set at elaboration time. Default values are optimized
for the PYNQ-Z2:

| Parameter | Default | Description |
|---|---|---|
| AXI_ADDR_WIDTH | 32 | AXI address bus width |
| AXI_DATA_WIDTH | 32 | AXI data bus width |
| AXIS_DATA_WIDTH | 32 | AXI-Stream data width |
| DATA_WIDTH | 8 | INT8 data width |
| ACCUM_WIDTH | 32 | INT32 accumulator width |
| ARRAY_ROWS | 20 | Systolic array rows (PEs per column) |
| ARRAY_COLS | 8 | Systolic array columns (output channels per tile) |
| BUFFER_DEPTH | 1024 | Activation buffer depth |
| BUFFER_ADDR_WIDTH | 10 | Buffer address width (log2(BUFFER_DEPTH)) |
| MAX_WIDTH | 128 | Maximum supported input image width |
| TILE_SIZE | 160 | Weight tile size = ARRAY_ROWS x ARRAY_COLS |

---

## 5. Interface Reference

### Clock and Reset

| Port | Direction | Description |
|---|---|---|
| aclk | Input | System clock (125 MHz recommended) |
| aresetn | Input | Active-low synchronous reset |

### AXI4-Lite Slave (S_AXI) -- Control

Standard AXI4-Lite slave interface. Used by the host CPU to configure
registers and read status.

- Address width: 32 bits
- Data width: 32 bits
- Supports byte-lane write strobes

### AXI4-Full Master (M_AXI) -- DMA

Standard AXI4-Full master interface. Used by the DMA controller to:
- Burst-read weight data from DDR (AR/R channels)
- Burst-write output data to DDR (AW/W/B channels)

- Address width: 32 bits
- Data width: 32 bits
- Burst length: up to 256 beats (8-bit arlen)
- Burst type: INCR

### AXI4-Stream Slave (S_AXIS) -- Input

Streaming input for activation data (pixel/feature map).

- Data width: 32 bits (4 channels per beat)
- No TKEEP, TID, TDEST, TUSER signals
- TLAST marks end of frame

### AXI4-Stream Master (M_AXIS) -- Output

Streaming output of processed results.

- Data width: 32 bits (4 channels per beat)
- TLAST marks end of output frame

### Miscellaneous

| Port | Direction | Description |
|---|---|---|
| vid_locked_in | Input | HDMI/video lock status. Tie to 1'b1 if unused |
| tile_count_in | Input | External tile counter. Tie to 32'd0 if unused |
| interrupt | Output | Asserts when status_done and csr_irq_en are both 1 |

---

## 6. CSR Register Map

| Offset | Name | R/W | Bits | Description |
|---|---|---|---|---|
| 0x00 | CTRL | W | [0]: start, [1]: soft_reset, [4]: wgt_bank_sel, [5]: cosine_sim | Start inference; configure mode |
| 0x04 | STATUS | R | [0]: idle, [1]: busy, [2]: done, [3]: error | Inference status |
| 0x08 | WEIGHT_BASE | R/W | [31:0] | DMA weight source address in DDR |
| 0x0C | ACT_BASE | R/W | [31:0] | DMA activation source address |
| 0x10 | OUT_BASE | R/W | [31:0] | DMA output destination address |
| 0x14 | LAYER_CFG_0 | R/W | [7:0]: InC, [15:8]: OutC, [23:16]: W, [31:24]: H | Layer geometry |
| 0x18 | LAYER_CFG_1 | R/W | [7:0]: kernel, [15:8]: stride, [23:16]: padding | Conv parameters |
| 0x1C | LAYER_CFG_2 | R/W | [15:0]: tiles_x, [31:16]: tiles_y | Tiling configuration |
| 0x20 | SCALE_M0 | R/W | [31:0] | Requantization scale (M0 multiplier) |
| 0x24 | SHIFT_N | R/W | [5:0] | Requantization right-shift (n) |
| 0x28 | IRQ_CTRL | R/W | [0]: irq_en | Enable inference-done interrupt |

### Basic Inference Sequence

```
1. Write WEIGHT_BASE = address of weights in DDR
2. Write OUT_BASE = address for output in DDR
3. Write LAYER_CFG_0 = {H, W, OutC, InC}
4. Write LAYER_CFG_1 = {padding, stride, kernel}
5. Write LAYER_CFG_2 = {tiles_y, tiles_x}
6. Write IRQ_CTRL = 1 (enable interrupt)
7. Start streaming activation data on S_AXIS
8. Write CTRL = 1 (start)
9. Poll STATUS[2] (done) or wait for interrupt
10. Read results from OUT_BASE address via AXI master
```

---

## 7. Simulation Quick Start

### Windows (One-Click)

```
Double-click: run_simulation.bat
```

Requires Vivado 2025.1 installed at D:/2025.1/Vivado/

### Command Line

```bash
"D:/2025.1/Vivado/bin/vivado.bat" -mode batch -source run_all.tcl
```

### Portable Script (Path-Independent)

```bash
"<vivado_install>/bin/vivado" -mode batch -source scripts/run_simulation_portable.tcl
```

### Expected Output

```
TOTAL TESTS : 5
PASSED      : 5
FAILED      : 0
SIMULATION PASSED
```

> **Note:** run_all.tcl contains a hardcoded Windows path (D:/Final year project/...).
> Use scripts/run_simulation_portable.tcl for a path-independent alternative.

---

## 8. Hardware Integration

### Constraints

For PYNQ-Z2 hardware implementation, use tinynpu_master.xdc which defines:
- HDMI RX/TX pin assignments (TMDS)
- Clock period definition (74.25 MHz HDMI pixel clock)
- False path exceptions for clock domain crossing

### Synthesis

All RTL files are pure behavioral Verilog-2001 with no FPGA primitives.
Synthesis is performed by Vivado synthesis (Vivado Synthesis 2025.1).

### Implementation Notes

- Assign 256 bytes of AXI address space to S_AXI
- Connect M_AXI to HP AXI slave port (DDR access)
- Clock: 125 MHz from PS7 FCLK_CLK0
- Reset: from Processor System Reset IP (peripheral_aresetn)

---

## 9. Software Driver Overview (PYNQ)

For PYNQ-Z2 deployment, a Python driver reads/writes CSRs via the PYNQ
mmio interface:

```python
from pynq import Overlay, MMIO

# Load overlay
overlay = Overlay('tinynpu200.bit')

# Direct MMIO access
npu = MMIO(base_address=0x43C00000, length=256)

# Configure layer
npu.write(0x08, weight_addr)   # WEIGHT_BASE
npu.write(0x14, layer_cfg_0)   # LAYER_CFG_0
npu.write(0x00, 0x1)           # CTRL: start

# Wait for completion
while (npu.read(0x04) & 0x4) == 0:
    pass  # Poll STATUS[done]
```

*Full driver implementation: To be provided to authorized users.*

---

## 10. Troubleshooting

| Problem | Likely Cause | Solution |
|---|---|---|
| IP not in Vivado catalog | IP repository not added | Tools > Settings > IP > Repository > Add parent of IP/TinyNPU200/ |
| status_done never asserts | CTRL write byte order issue | Ensure all 4 bytes of CTRL are written; AXI4-Lite uses byte strobes |
| All X in simulation output | Weight bank not primed | Run two inferences; first primes the ping-pong buffer |
| Simulation path error | run_all.tcl hardcoded path | Use scripts/run_simulation_portable.tcl instead |
| Timing failure at >125 MHz | Routing congestion | Reduce clock frequency or apply timing exceptions in XDC |
| DMA hangs after arvalid | AXI slave missing burst support | Ensure the AXI slave responds to m_axi_arlen correctly |
| Synthesis drops DSPs | Wrong PE bit-widths | Inputs are sign-extended to 18 bits internally; no action needed |
| Missing dummy_weights.hex | File not included | Check IP/TinyNPU200/src/ and sim/ directories |

---

*Copyright (c) 2026 Hariharan Ganesh. All rights reserved.*  
*Email: hariharanganesh67@gmail.com*
