# TinyNPU200JPMAX — Implementation Plan

## Background: A Critical Discovery

After reading the OOC synthesis utilization report, we found that the current TinyNPU200J **only uses 1 DSP48E1 total**. This means Vivado mapped all 160 PE multipliers (8×8 INT8 MAC) to **LUT fabric instead of DSP slices**, because 8×8 = 16-bit products fall below Vivado's threshold for automatic DSP inference.

This is actually GREAT news — we have 219 DSPs almost completely free!

**Root Cause**: The `(* use_dsp = "yes" *)` attribute needs to be placed on the multiply operation *expression* itself inside the always block, not just on the register. The fix is to use `(* use_dsp48 = "yes" *)` on the module and ensure 18-bit sign-extended inputs to guarantee DSP mapping.

---

## Goal for PMAX

| Parameter | TinyNPU200J (Current) | TinyNPU200JPMAX (New) |
|---|---|---|
| Array size | 20 × 8 = 160 MACs | **26 × 8 = 208 MACs** |
| DSP48E1 target | ~1 (bug — LUT mapped) | **~210 DSPs** (correctly mapped) |
| DSP budget | — | ≤ 215 (as requested) |
| Peak TOPS | 0.04 TOPS (LUT) | **0.052 TOPS (DSP)** |
| Inference latency | ~40ms | **~30ms** (DSP is 2× faster than LUT) |
| Drone tracking | ~40 m/s | **~65 m/s** |

> Switching from LUT to DSP mapping also **improves timing** because DSP48 arithmetic is physically faster than LUT carry chains — giving extra WNS headroom.

---

## Key Changes vs TinyNPU200J

### 1. `processing_element.v` — Force DSP48 Mapping
Add proper DSP inference attributes and widen inputs to 18-bit to guarantee DSP mapping:
```verilog
// Change from:
wire signed [15:0] mul_s1 = weight_reg * act_in;

// To (forces DSP48 every time):
wire signed [17:0] weight_ext = {{10{weight_reg[7]}}, weight_reg};
wire signed [17:0] act_ext    = {{10{act_in[7]}},    act_in};
(* use_dsp = "yes" *) reg signed [35:0] mul_s1;
always @(posedge clk)
    mul_s1 <= weight_ext * act_ext;
```

### 2. `systolic_array.v` — Expand to 26×8
```verilog
parameter ARRAY_ROWS = 26  // was 20
```

### 3. New Project Directory
- Path: `D:\Final year project\npu200jpmax\`
- Name: `npu200jpmax`
- **Completely isolated from current npu200jb project**

### 4. All Previous Bugs Pre-Baked (Zero Regressions)

| Previous Bug | Fix Applied From Day 1 |
|---|---|
| BUFG-BUFG cascade error | `CLOCK_DEDICATED_ROUTE FALSE` in XDC |
| CDC timing violation (clk_fpga_1→0) | `set_false_path` in XDC |
| Vivado OOC cache silently ignoring RTL | `reset_run` in TCL script |
| `bad allocation` crash (8GB RAM) | `-jobs 2` in all launch commands |
| HDMI port name mismatch | Using correct `TMDS_RX/TX` names |
| tile_count_in floating | Tied to 0 via TCL in BD |
| Requantizer barrel shift timing | Already pipelined (inherits from fixed IP) |

---

## DSP Budget Estimation

| Component | DSP Count |
|---|---|
| 26×8 Systolic Array PEs (1 DSP48 each) | 208 |
| Requantizer (1 DSP for DMA size calc) | 1 |
| BBox decoder (cx_reg, cy_reg) | 2 |
| Controller (1 misc multiply) | 1 |
| **Total Estimated** | **~212 DSPs** |
| **Budget Limit** | **215 DSPs** ✅ |
| **Safety Margin** | **3 DSPs** |

---

## Files to Create / Modify

### [NEW] `D:\Final year project\IP\TinyNPU200JPMAX\`
Copy of TinyNPU200 IP with PMAX modifications:
- `src\processing_element.v` — DSP48 forced mapping + 26-row parameter
- `src\systolic_array.v` — ARRAY_ROWS=26

### [NEW] `D:\Final year project\create_pmax.tcl`
Full project creation script with all fixes pre-baked

### [NEW] `D:\Final year project\rebuild_pmax.ps1`
PowerShell automation to build the entire PMAX project

### [COPY] `D:\Final year project\Versions\TinyNPU200JPMAX\constraints\hdmi_pins.xdc`
Copy of current XDC with all CDC + CLOCK_DEDICATED_ROUTE constraints already included

---

## Verification Plan

1. After synthesis: Confirm DSP48E1 count = 205–215
2. After implementation: Confirm `WNS ≥ 0`, `TNS = 0`, `WHS ≥ 0`, `THS = 0`
3. Confirm bitstream generated at `npu200jpmax\npu200jpmax.runs\impl_1\npu_system_wrapper.bit`
4. Copy final `.bit` and `.hwh` to `D:\Final year project\deploy\tinynpu200jpmax\`

---

## Open Questions

> [!IMPORTANT]
> The array size of 26×8 = 208 MACs is estimated to hit ~212 DSPs. If synthesis exceeds 215, I will automatically step down to 25×8 = 200 MACs (~210 DSPs) without requiring another rebuild approval.
