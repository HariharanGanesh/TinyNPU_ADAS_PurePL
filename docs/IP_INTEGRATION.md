# IP Integration Guide — TinyNPU200

> Copyright (C) 2026 Hariharan Ganesh. All rights reserved.
> **Authorization required before integration. See [ACCESS.md](../ACCESS.md).**

---

## Overview

This guide explains how to integrate the TinyNPU200 IP core into a Vivado project.
It assumes you have received written authorization from the author.

**IP name:** `tinynpu_top`
**Vendor:** `ai.local`
**Version:** `1.0`
**Packaged format:** Vivado IP Repository (`component.xml`)

---

## Required Files

The following files must be present on your system:

| File | Purpose |
|---|---|
| `IP/TinyNPU200/component.xml` | IP packager descriptor (required for Vivado import) |
| `IP/TinyNPU200/src/*.v` | All 21 RTL source files |
| `IP/TinyNPU200/src/dummy_weights.hex` | Weight memory initialization file |
| `IP/TinyNPU200/sim/tb_tinynpu_top.sv` | Testbench |
| `IP/TinyNPU200/sim/dummy_weights.hex` | Simulation weight file |

---

## Step-by-Step Integration

### Step 1 — Add IP Repository in Vivado

1. Open Vivado 2025.1
2. In the Tools menu, select **Settings**
3. Navigate to **IP > Repository**
4. Click **+** (Add Repository)
5. Browse to the directory containing `IP/TinyNPU200/`
   - Select the **parent directory** that contains `TinyNPU200/` (the folder with `component.xml`)
6. Click **OK**
7. Vivado will detect `tinynpu_top v1.0` and add it to the catalog

### Step 2 — Add IP to Block Design

1. Open your Block Design
2. Click **+** to add IP
3. Search for `tinynpu_top`
4. Double-click to add it

Alternatively, instantiate directly in RTL (see Step 3).

### Step 3 — RTL Instantiation

Add the following to your top-level Verilog file:

```verilog
tinynpu_top #(
    .AXI_ADDR_WIDTH  (32),
    .AXI_DATA_WIDTH  (32),
    .AXIS_DATA_WIDTH (32),
    .DATA_WIDTH      (8),
    .ACCUM_WIDTH     (32),
    .ARRAY_ROWS      (20),
    .ARRAY_COLS      (8),
    .BUFFER_DEPTH    (1024),
    .BUFFER_ADDR_WIDTH (10),
    .MAX_WIDTH       (128),
    .TILE_SIZE       (160)
) u_tinynpu (
    // Clock and Reset
    .aclk             (aclk),
    .aresetn          (aresetn),

    // AXI4-Lite Slave (Control)
    .s_axi_awaddr     (s_axi_awaddr),
    .s_axi_awprot     (s_axi_awprot),
    .s_axi_awvalid    (s_axi_awvalid),
    .s_axi_awready    (s_axi_awready),
    .s_axi_wdata      (s_axi_wdata),
    .s_axi_wstrb      (s_axi_wstrb),
    .s_axi_wvalid     (s_axi_wvalid),
    .s_axi_wready     (s_axi_wready),
    .s_axi_bresp      (s_axi_bresp),
    .s_axi_bvalid     (s_axi_bvalid),
    .s_axi_bready     (s_axi_bready),
    .s_axi_araddr     (s_axi_araddr),
    .s_axi_arprot     (s_axi_arprot),
    .s_axi_arvalid    (s_axi_arvalid),
    .s_axi_arready    (s_axi_arready),
    .s_axi_rdata      (s_axi_rdata),
    .s_axi_rresp      (s_axi_rresp),
    .s_axi_rvalid     (s_axi_rvalid),
    .s_axi_rready     (s_axi_rready),

    // AXI4-Full Master (DMA)
    .m_axi_awaddr     (m_axi_awaddr),
    .m_axi_awlen      (m_axi_awlen),
    .m_axi_awsize     (m_axi_awsize),
    .m_axi_awburst    (m_axi_awburst),
    .m_axi_awvalid    (m_axi_awvalid),
    .m_axi_awready    (m_axi_awready),
    .m_axi_wdata      (m_axi_wdata),
    .m_axi_wstrb      (m_axi_wstrb),
    .m_axi_wlast      (m_axi_wlast),
    .m_axi_wvalid     (m_axi_wvalid),
    .m_axi_wready     (m_axi_wready),
    .m_axi_bresp      (m_axi_bresp),
    .m_axi_bvalid     (m_axi_bvalid),
    .m_axi_bready     (m_axi_bready),
    .m_axi_araddr     (m_axi_araddr),
    .m_axi_arlen      (m_axi_arlen),
    .m_axi_arsize     (m_axi_arsize),
    .m_axi_arburst    (m_axi_arburst),
    .m_axi_arvalid    (m_axi_arvalid),
    .m_axi_arready    (m_axi_arready),
    .m_axi_rdata      (m_axi_rdata),
    .m_axi_rresp      (m_axi_rresp),
    .m_axi_rlast      (m_axi_rlast),
    .m_axi_rvalid     (m_axi_rvalid),
    .m_axi_rready     (m_axi_rready),

    // AXI4-Stream Slave (Input)
    .s_axis_tdata     (s_axis_tdata),
    .s_axis_tvalid    (s_axis_tvalid),
    .s_axis_tready    (s_axis_tready),
    .s_axis_tlast     (s_axis_tlast),

    // AXI4-Stream Master (Output)
    .m_axis_tdata     (m_axis_tdata),
    .m_axis_tvalid    (m_axis_tvalid),
    .m_axis_tready    (m_axis_tready),
    .m_axis_tlast     (m_axis_tlast),

    // Video status
    .vid_locked_in    (1'b1),
    .tile_count_in    (32'd0),

    // Interrupt
    .interrupt        (npu_interrupt)
);
```

### Step 4 — Clock Connection

Connect `aclk` to a 125 MHz clock source.
On PYNQ-Z2, this is typically the PS7 FCLK_CLK0 configured for 125 MHz.

### Step 5 — Reset Connection

Connect `aresetn` to an active-low synchronous reset.
On Zynq systems, use the Processor System Reset IP output `peripheral_aresetn`.

### Step 6 — AXI Connection in Block Design

Typical connections for a Zynq-based system:

| TinyNPU200 Port | Connect To |
|---|---|
| `S_AXI` | AXI Interconnect Slave port (from PS GP AXI Master) |
| `M_AXI` | AXI Interconnect Master port (to DDR via HP AXI Slave) |
| `S_AXIS` | AXI4-Stream source (e.g., HDMI RX or DMA output) |
| `M_AXIS` | AXI4-Stream sink (e.g., HDMI TX or DMA input) |

### Step 7 — Address Map

Assign a base address to the `S_AXI` interface in Vivado Address Editor.
The IP requires 256 bytes (32 CSR registers x 4 bytes) of address space.

**Recommended base address:** `0x43C00000` (Zynq PL AXI range)

### Step 8 — Generate Output Products

Right-click the IP in Sources and select **Generate Output Products**.

### Step 9 — Synthesize and Implement

Run synthesis and implementation as normal. The IP uses only behavioral RTL
with no FPGA-specific primitives in `tinynpu_top.v` or its submodules.

---

## CSR Register Map (Summary)

| Offset | Register | Description |
|---|---|---|
| 0x00 | CTRL | Start bit [0], soft reset [1], bank_sel [4], cosine_sim [5] |
| 0x04 | STATUS | Idle [0], busy [1], done [2], error [3] |
| 0x08 | WEIGHT_BASE | DMA weight source address |
| 0x0C | ACT_BASE | DMA activation source address |
| 0x10 | OUT_BASE | DMA result destination address |
| 0x14 | LAYER_CFG_0 | InC[7:0], OutC[15:8], W[23:16], H[31:24] |
| 0x18 | LAYER_CFG_1 | Kernel[7:0], Stride[15:8], Padding[23:16] |
| 0x1C | LAYER_CFG_2 | Tiles_X[15:0], Tiles_Y[31:16] |
| 0x20 | SCALE_M0 | Requantization scale factor |
| 0x24 | SHIFT_N | Requantization right-shift |
| 0x28 | IRQ_CTRL | IRQ enable [0] |

*Full register map available in the USER_MANUAL.md*

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| IP not found in Vivado catalog | IP repo path not added | Add `IP/TinyNPU200/` parent directory in Settings > IP > Repository |
| `status_done` never asserts | Start bit not written correctly | Verify byte-lane write sequence; write all 4 bytes of CTRL |
| Output all X in simulation | Weight bank not primed | Run two inferences; Inference 1 primes the bank, Inference 2 gives valid results |
| Timing failure | Clock > 125 MHz | Reduce clock or apply timing exceptions |
| DMA hangs | AXI slave not responding | Ensure AXI slave supports burst reads with `m_axi_arlen` beats |

---

*Copyright (C) 2026 Hariharan Ganesh. All rights reserved.*
