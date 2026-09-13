# TinyNPU200A — Synthesis & Implementation Report

> **Design:** `tinynpu_top` (npu_system_wrapper)
> **Device:** Xilinx Zynq-7020 · Package clg400 · Speed Grade -1
> **Tool:** Vivado 2025.1 (Build 6140274)
> **Date:** September 2026

---

## 1 · Design Timing Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Worst Negative Slack (WNS)** | **+0.163 ns** | PASS |
| Total Negative Slack (TNS) | 0.000 ns | PASS |
| Failing Setup Endpoints | 0 / 39,430 | PASS |
| **Worst Hold Slack (WHS)** | **+0.020 ns** | PASS |
| Total Hold Slack (THS) | 0.000 ns | PASS |
| Failing Hold Endpoints | 0 / 39,430 | PASS |
| Worst Pulse Width Slack (WPWS) | +4.500 ns | PASS |

All timing constraints are **MET** with positive slack. The design is timing-closed at **125 MHz** on the `aclk` domain.

---

## 2 · Resource Utilization Summary

| Resource | Used | Available | Utilisation |
|----------|------|-----------|-------------|
| **LUTs (Logic)** | **14,008** | 53,200 | **26.33 %** |
| Slice Registers (FFs) | 16,284 | 106,400 | 15.30 % |
| Slices | 5,160 | 13,300 | 38.80 % |
| Block RAM Tiles | 13 | 140 | 9.29 % |
|   RAMB36E1 | 2 | 140 | 1.43 % |
|   RAMB18E1 | 22 | 280 | 7.86 % |
| **DSP48E1 (MACs)** | **204** | 220 | **92.73 %** |

The DSP utilisation of **92.73%** reflects the dense INT8 MAC array of the **20x8 weight-stationary systolic array**, the primary compute fabric of TinyNPU200A.

---

## 3 · Primitive Breakdown

| Primitive | Count | Function |
|-----------|-------|----------|
| DSP48E1 | 204 | INT8 Multiply-Accumulate (Systolic Array) |
| LUT2 | 11,203 | 2-input combinational logic |
| FDCE | 10,498 | Clock-enabled flip-flops (async clear) |
| FDRE | 5,769 | Clock-enabled flip-flops (sync reset) |
| LUT3 | 5,480 | 3-input combinational logic |
| CARRY4 | 2,518 | Fast carry chains (adders/comparators) |
| LUT6 | 2,978 | 6-input combinational logic |
| RAMB18E1 | 22 | 18Kb Block RAMs (weights, buffers) |
| RAMB36E1 | 2 | 36Kb Block RAMs (instruction BRAMs) |

---

## 4 · ADAS Subsystem Verification

The `riscv_adas_subsystem` and its constituent modules (`sensor_fusion`, `safety_unit`,
`security_unit`) were verified with a dedicated SystemVerilog testbench (`verification/tb/tb_adas_features.sv`).

All 5 safety-critical scenarios **PASSED**:

| # | Scenario | Result |
|---|----------|--------|
| 1 | Pedestrian detected -> brakes applied | PASS |
| 2 | Brake switch disarmed -> brakes blocked by security unit | PASS |
| 3 | Critical lane departure -> lane warning + brakes applied | PASS |
| 4 | Speed sign overspeed -> sign warning triggered | PASS |
| 5 | WDT timeout -> system fault latched -> brakes locked off | PASS |

### ADAS Behavioral Simulation Waveform (Vivado 2025.1 xsim)

![ADAS Behavioral Simulation Waveform](../images/adas_simulation_waveform.png)

All stimulus is driven on the **negative clock edge**, ensuring clean setup/hold margins
and a visible realistic 1-cycle (8 ns) propagation delay in the waveform.

---

## 5 · Bug Fix: sensor_fusion Hazard Score (ISO 26262 Compliance)

A critical safety defect was identified and corrected in `IP/RISCV_ADAS_Controller/src/sensor_fusion.v`.

**Root Cause:** Pedestrian detection contributed only `+1` to the hazard score threshold,
never crossing the `>= 3` emergency threshold when detected in isolation.
The AI would not apply brakes for a lone pedestrian — a critical ASIL violation.

**Fix Applied:** Hazard contributions re-weighted by physical severity.

```verilog
// BEFORE (BUG):
assign hazard_score = (ped_detected & ped_en) + (obs_detected & obs_en) + ...

// AFTER (FIX): ISO 26262-aligned severity weighting
assign hazard_score = ((ped_detected & ped_en) ? 3''d4 : 3''d0) +
                      ((obs_detected  & obs_en) ? 3''d3 : 3''d0) +
                      ((lane_detected & lane_en) ? {1''b0, lane_severity} : 3''d0) +
                      (sign_overspeed            ? 3''d1 : 3''d0);
```

| Hazard Source | Score | Triggers Emergency? |
|---------------|-------|---------------------|
| Pedestrian (`ped_detected`) | 4 | Yes (immediate) |
| Obstacle (`obs_detected`) | 3 | Yes (immediate) |
| Critical Lane Departure (severity=3) | 3 | Yes |
| Speed Sign | 1 | No (warning only) |

---

## 6 · Constraint Notes

- Duplicate `pynq_z2_customized.xdc` reference from project root removed; canonical file is `constraints/pynq_z2_customized.xdc`.
- Digilent `dvi2rgb` IP `NDRV-1` DRC severity downgraded to WARNING via `-quiet` (known-safe differential I/O routing deviation).
- HDMI E2E testbench (`sim_hdmi_e2e`) and ADAS unit testbench (`sim_adas_features`) both active in Vivado project.

---

*TinyNPU ADAS Pure-PL — Final Year Project, 2026.*