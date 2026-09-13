# RISC-V-Based-FPGA-Automotive-ADAS-Zonal-Controller

![Vivado](https://img.shields.io/badge/Xilinx-Vivado_2024.1-FF6900?style=flat&logo=xilinx)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![RISC-V](https://img.shields.io/badge/RISC--V-PicoRV32-283272?style=flat)
![Cadence](https://img.shields.io/badge/Cadence-Genus_%7C_Innovus-0033A0?style=flat)
![FPGA](https://img.shields.io/badge/FPGA-Spartan--7_XC7S50-FF6900?style=flat)

A complete FPGA-based Automotive ADAS SoC prototype with 8 functional blocks including a RISC-V control unit (PicoRV32), AI decision accelerator, functional safety unit, and ISO-26262 inspired security logic. Verified 28/28 test scenarios in Cadence NCLaunch simulation with zero failures and completed physical design flow from RTL synthesis (Cadence Genus) to GDSII (Cadence Innovus) with timing closure at 100 MHz.

**Author:** Hariharan Ganesh, Kamalesh S — Saveetha Engineering College

---

## Table of Contents

- [Project Status](#project-status)
- [Hardware Platform](#hardware-platform)
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [RTL Design](#rtl-design)
- [Simulation Results](#simulation-results)
- [FPGA Implementation](#fpga-implementation)
- [Synthesis — Cadence Genus](#synthesis--cadence-genus)
- [Physical Design — Cadence Innovus](#physical-design--cadence-innovus)
- [Python ML Integration](#python-ml-integration)
- [UART Protocol](#uart-protocol)
- [Hardware I/O Mapping](#hardware-io-mapping)
- [Hardware Test Quick Reference](#hardware-test-quick-reference)
- [Known Issues and Fixes](#known-issues-and-fixes)
- [Setup and Usage](#setup-and-usage)

---

## Project Status

| Phase | Status |
|---|---|
| RTL Design | ✅ DONE |
| Simulation — Vivado + Cadence NCLaunch | ✅ DONE — 28/28 PASSED |
| Synthesis — Cadence Genus | ✅ DONE |
| Physical Design RTL-to-GDSII — Cadence Innovus | ✅ DONE |
| FPGA Bitstream Generation — Vivado | ✅ DONE |
| Python ML Integration | ✅ DONE |
| Hardware Testing on Spartan-7 | 🔄 IN PROGRESS |

---

## Hardware Platform

| Parameter | Value |
|---|---|
| Board | Spartan-7 Boolean Board |
| FPGA Part | XC7S50CSGA324-1 |
| Clock | 100 MHz onboard oscillator |
| EDA Tool | Xilinx Vivado 2022.x |

---

## Architecture Overview

The system is organized into 8 functional blocks:
<img width="767" height="853" alt="image" src="https://github.com/user-attachments/assets/417e8acf-fbfd-4593-9378-4c6b6e7f5777" />

| Block | Module | Description |
|---|---|---|
| Block 1 | Python + YOLOv8 | Image Scenario Engine (runs on laptop) |
| Block 2 | `riscv_control_unit.v` | PicoRV32-based RISC-V FSM Controller |
| Block 3 | `ai_accelerator.v` | Edge AI threshold + FSM risk evaluation |
| Block 4 | `sensor_fusion.v` | Multi-signal danger combiner |
| Block 5 | `uart_rx.v` + `uart_tx.v` | Full-duplex UART communication |
| Block 6 | `safety_unit.v` | Watchdog + fault detection + brake control |
| Block 7 | `security_unit.v` | SW6 brake authorization FSM interlock |
| Block 8 | `supporter_module.v` | BRAM + LED controller + 7-segment driver |

---

## Repository Structure

```
RISC-V-Based-FPGA-Automotive-ADAS-Zonal-Controller/
│
├── README.md
├── .gitignore
│
├── rtl/                              ← Synthesisable Verilog RTL
│   ├── top.v                         ← Top-level SoC integration
│   ├── riscv_control_unit.v          ← PicoRV32-based RISC-V FSM (Block 2)
│   ├── picorv32.v                    ← Open-source PicoRV32 RV32IMC core
│   ├── ai_accelerator.v              ← Edge AI threshold + FSM (Block 3)
│   ├── sensor_fusion.v               ← Multi-condition combiner (Block 4)
│   ├── safety_unit.v                 ← Watchdog + brake (Block 6)
│   ├── security_unit.v               ← SW6 brake interlock FSM (Block 7)
│   ├── uart_rx.v                     ← UART receiver + ASCII parser (Block 5)
│   ├── uart_tx.v                     ← UART transmitter + warning encoder (Block 5)
│   └── supporter_module.v            ← LED controller, XADC reader, Seg7, debouncer
│
├── tb/                               ← Verilog/SystemVerilog Testbenches
│   ├── combined_tb.v                 ← 3-scenario combined testbench (Vivado)
│   ├── top_tb.v                      ← Full 4-scenario system testbench
│   ├── ai_accelerator_tb.v           ← Block 3 unit test
│   ├── fusion_safety_tb.v            ← Block 4 + 6 unit tests
│   ├── uart_tb.v                     ← UART loopback test
│   └── system_fsm_tb.v               ← FSM integration test + VCD dump
│
├── sim/
│   └── filelist/
│       ├── rtl.f                     ← VCS / Vivado XSim RTL filelist
│       ├── tb.f                      ← Testbench filelist
│       └── rtl_nclaunch.f            ← Cadence NCLaunch filelist
│
├── fpga/
│   ├── constraints/
│   │   └── top.xdc                   ← Spartan-7 Boolean Board pin constraints
│   ├── scripts/
│   │   └── vivado_build.tcl          ← Full build: synth → impl → bitstream
│   ├── reports/
│   │   ├── utilization.rpt
│   │   ├── timing.rpt
│   │   ├── power.rpt
│   │   └── drc.rpt
│   └── bitstream/
│       ├── soc_top_demo.bit          ← FPGA bitstream (program with HW Manager)
│       └── soc_top_demo.bin
│
├── synthesis/
│   ├── genus/                        ← Cadence Genus ASIC synthesis
│   │   ├── scripts/
│   │   │   ├── script.tcl            ← Complete Genus synthesis script
│   │   │   └── constraints.sdc       ← 100 MHz clock, I/O delays, false paths
│   │   ├── reports/
│   │   │   ├── area.rpt
│   │   │   ├── timing.rpt
│   │   │   ├── power.rpt
│   │   │   └── gates.rpt
│   │   └── netlist/
│   │       ├── soc_top_netlist.v
│   │       ├── soc_top.sdc
│   │       └── soc_top.sdf
│   └── innovus/                      ← Cadence Innovus Place & Route
│       ├── scripts/
│       ├── reports/
│       └── results/
│           ├── final.gds             ← GDSII layout output
│           └── final.def
│
├── python/
│   ├── main.py                       ← Image-based ADAS detection + UART send
│   ├── config.py                     ← Serial port and threshold configuration
│   ├── uart_fpga.py                  ← UART communication class
│   ├── pedestrian_detector.py        ← YOLOv8 person detection (COCO class 0)
│   ├── lane_detector.py              ← OpenCV Canny + Hough lane detection
│   ├── sign_detector.py              ← YOLOv8 stop sign + red circle detection
│   ├── obstacle_detector.py          ← YOLOv8 vehicle detection in forward zone
│   └── test_no_fpga.py               ← Test detections without FPGA connected
│
├── docs/
│   └── images/
│       ├── simulation/               ← NCLaunch waveform screenshots
│       │   ├── scenario1_pedestrian.png
│       │   ├── scenario2_lane.png
│       │   ├── scenario3_collision.png
│       │   ├── scenario4_sign.png
│       │   ├── scenario7_trafficjam.png
│       │   ├── scenario11_corrupted_uart.png
│       │   └── all_28_pass.png
│       ├── fpga/                     ← Vivado schematic, device view, reports
│       │   ├── vivado_schematic.png
│       │   ├── vivado_device_view.png
│       │   ├── utilization_report.png
│       │   ├── timing_report.png
│       │   └── power_report.png
│       ├── synthesis/                ← Genus report screenshots
│       │   ├── genus_area.png
│       │   ├── genus_timing.png
│       │   └── genus_power.png
│       ├── pnr/                      ← Innovus floorplan, placement, route, GDSII
│       │   ├── floorplan.png
│       │   ├── placement.png
│       │   ├── cts.png
│       │   ├── routing.png
│       │   ├── 3d_view.png
│       │   └── gdsii.png
│       └── board/                    ← Hardware demo photos + UART terminal
│           ├── board_overview.png
│           ├── board_pedestrian_test.png
│           ├── board_lane_test.png
│           ├── board_collision_test.png
│           ├── board_sign_test.png
│           └── uart_terminal.png
│
└── sw/
    ├── demo.S                        ← Assembly: UART print + GPIO mirror + Seg7
    ├── link.ld                       ← Linker script
    ├── Makefile                      ← riscv64-unknown-elf toolchain build rules
    ├── bin2mem.py                    ← ELF → $readmemh hex converter
    └── program.mem                   ← Pre-built hex image for imem.v
```

---

## RTL Design

### Top-Level Port List (`top.v`)

```verilog
module top (
    input  wire        clk,
    input  wire        sw0, sw1, sw2, sw3,
    input  wire [1:0]  sw_lane_sev,
    input  wire        sw6,
    input  wire        btn0, btn1, btn2, btn3,
    input  wire [11:0] xadc_data,
    input  wire        uart_rx,
    output wire        uart_tx,
    output wire        led0, led1, led2, led3, led4, led5,
    output wire [7:0]  seg,
    output wire [3:0]  an
);
```

> **Notes:**
> - `rst_n` removed — `btn3` is the sole system reset
> - `seg` is `[7:0]` — `seg[7]` maps to DP pin on Boolean Board
> - `xadc_data` tied to `12'd0` in hardware; XADC IP reads internally via `supporter_module.v`

### AI Accelerator Speed Thresholds

| Parameter | Value | Effect |
|---|---|---|
| `SPEED_LOW` | 30 km/h | `ped_danger`, `col_danger` start |
| `SPEED_MED` | 60 km/h | `brake_request` fires |
| `SPEED_HIGH` | 90 km/h | `emergency_priority`, `col_critical` |
| `speed_limit` | 40 km/h | Set by Python `'s'` command — overspeed check |

### Security Unit FSM

```
LOCKED ──(sw6=ON)──▶ VERIFY ──(emergency_brake=1)──▶ UNLOCKED
                                                           │
LOCKED ◀──(BTN3)── PROTECTED ◀──(emergency clears)────────┘

brake_authorized = 1  ONLY in UNLOCKED state
```

### Sensor Fusion — Sticky Latch Behaviour

`emergency_state` is a sticky latch — once HIGH it stays HIGH until **both** BTN3 and Python `b'r'` are pressed together. This prevents a UART glitch from clearing an active emergency.

### Safety Unit

- Watchdog timeout: 10,000,000 cycles = 100 ms
- `fault_latch`: set on watchdog timeout, cleared by BTN3
- `emergency_brake` = `brake_priority AND sw6_brake_en`

---

## Simulation Results

**Tool:** Cadence NCLaunch — ncsim 15.20-s086 + SimVision
**Testbench:** `combined_tb.v`
**Total simulation time:** 2,357,600 ns

| Scenario | Description | Expected LEDs | Result |
|---|---|---|---|
| 1 | Pedestrian Detection | LED1 + LED4 + LED5 | ✅ PASS |
| 2 | Lane Departure | LED2 + LED4 | ✅ PASS |
| 3 | Collision Warning | LED4 + LED5 | ✅ PASS |
| 4 | Traffic Sign Overspeed | LED3 + LED4 | ✅ PASS |
| 5 | Safe Mode | All OFF | ✅ PASS |
| 6 | Safe Pedestrian (low speed) | LED1 only | ✅ PASS |
| 7 | Traffic Jam (multi-hazard) | LED1 + LED2 + LED4 + LED5 | ✅ PASS |
| 8 | Manual Brake via BTN2 | LED5 | ✅ PASS |
| 9 | Brake Disabled (sw6=OFF) | LED4 only | ✅ PASS |
| 10 | Low Speed Lane Warning | LED2 only | ✅ PASS |
| 11 | Corrupted UART Input | No false trigger | ✅ PASS |
| 12 | Reset Recovery | All cleared | ✅ PASS |

**Total: 28 / 28 PASSED — 0 FAILED**

> Waveform screenshots: `docs/images/simulation/`

![Simulation All Pass](docs/images/simulation/all_28_pass.png)

---

## FPGA Implementation

**Target:** XC7S50CSGA324-1 (Spartan-7 Boolean Board) — 100 MHz

### Utilization Summary

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 1,165 | 32,600 | 3.57% |
| LUT as Logic | 1,121 | 32,600 | 3.44% |
| LUT as Memory | 44 | 9,600 | 0.46% |
| Slice Registers (FFs) | 711 | 65,200 | 1.09% |
| DSP48E1 | 1 | 120 | 0.83% |
| Bonded IOB | 31 | 210 | 14.76% |
| BRAM | 0 | — | 0% |

### Timing Summary

| Check | WNS | Failing Endpoints | Status |
|---|---|---|---|
| Setup | +0.654 ns | 0 | ✅ MET |
| Hold | +0.049 ns | 0 | ✅ MET |
| Pulse Width | +3.750 ns | 0 | ✅ MET |

Critical path: 13 logic levels (CARRY4=6, LUT2=1, LUT4=2, LUT5=2, LUT6=2)

### Power Summary

| Component | Power |
|---|---|
| Total On-Chip Power | 106 mW |
| Dynamic Power | 34 mW |
| Static Power | 72 mW |

### DRC

0 violations

> FPGA screenshots: `docs/images/fpga/`

![Vivado Device View](docs/images/fpga/vivado_device_view.png)
![Timing Report](docs/images/fpga/timing_report.png)

---

## Synthesis — Cadence Genus

**Library:** 90 nm `slow.lib`
**Clock:** 100 MHz (10 ns period)

### Area Report

| Metric | Value |
|---|---|
| Total Cell Area | 55,402.8 µm² |
| Combinational Cells | 4,133 |
| Sequential Cells | 1,715 |
| Total Cells | 5,848 |

### Timing Report

| Metric | Value |
|---|---|
| WNS | +0.127 ns |
| TNS | 0.000 ns |
| Failing Endpoints | 0 |
| Status | ✅ MET |

### Power Report

| Component | Power |
|---|---|
| Total Power | 3.39 mW |
| Leakage Power | 0.291 mW |
| Internal Power | 2.915 mW |
| Switching Power | 0.182 mW |

> Genus screenshots: `docs/images/synthesis/`

![Genus Area Report](docs/images/synthesis/genus_area.png)
![Genus Timing Report](docs/images/synthesis/genus_timing.png)

---

## Physical Design — Cadence Innovus

### Post-Route Results

| Metric | Value |
|---|---|
| Total Instances | 5,867 |
| Setup WNS | +0.328 ns ✅ MET |
| Total Power | 3.92 mW |
| DRC Violations | 0 |
| Output | `final.gds` (GDSII) + `final.def` |

DRC checks passed: Cells, SameNet, Wiring, Antenna — all 0 violations.

> PnR screenshots: `docs/images/pnr/`

![Floorplan](docs/images/pnr/floorplan.png)
![Routing](docs/images/pnr/routing.png)
![GDSII](docs/images/pnr/gdsii.png)

---

## Python ML Integration

**Environment:** VS Code on laptop
**Models:** YOLOv8n (auto-downloads on first run, ~6 MB)
**Images:** Place test images in `./images/` folder

### Install Dependencies

```bash
pip install ultralytics opencv-python pyserial numpy
```

### Run

```bash
# Test without FPGA connected
python test_no_fpga.py

# Run with FPGA connected
python main.py
```

### Controls

| Key | Action |
|---|---|
| `SPACE` | Load next image |
| `R` | Reset FPGA state |
| `ESC` | Quit |

### Detection Modules

| File | Description |
|---|---|
| `pedestrian_detector.py` | YOLOv8 person detection (COCO class 0) |
| `lane_detector.py` | OpenCV Canny + Hough lane detection |
| `sign_detector.py` | YOLOv8 stop sign + red circle detection |
| `obstacle_detector.py` | YOLOv8 vehicle detection in forward zone |

---

## UART Protocol

**Baud rate:** 9600, 8N1, ASCII single-byte mode

### Python → FPGA

| Byte | ASCII | Meaning |
|---|---|---|
| `0x70` | `'p'` | `pedestrian_detected = 1` |
| `0x6C` | `'l'` | `lane_detected = 1`, `lane_severity = 11` |
| `0x73` | `'s'` | `sign_detected = 1`, `speed_limit = 40` |
| `0x6F` | `'o'` | `obs_detected = 1` |
| `0x72` | `'r'` | Reset all flags to 0 |

### FPGA → Python

| Byte | ASCII | Meaning |
|---|---|---|
| `0x50` | `'P'` | Pedestrian warning |
| `0x42` | `'B'` | Brake activated |
| `0x43` | `'C'` | Collision warning |
| `0x4C` | `'L'` | Lane departure |
| `0x53` | `'S'` | Sign overspeed |

---

## Hardware I/O Mapping

### Switches

| Switch | Function |
|---|---|
| SW0 | Pedestrian detection mode — gates LED1 |
| SW1 | Lane detection mode — gates LED2 |
| SW2 | Traffic sign detection mode — gates LED3 |
| SW3 | Collision mode — gates LED4 |
| SW4 + SW5 | Lane severity (`11` = dangerous, triggers LED4 via sensor fusion) |
| SW6 | **Emergency brake enable — PHYSICAL SAFETY KEY** — gates LED5 |

### Buttons

| Button | Function |
|---|---|
| BTN0 | Start FSM (press once before sending Python commands) |
| BTN2 | Emergency trigger (activates LED4 + LED5 without Python) |
| BTN3 | System reset (clears all detection states) |

### Potentiometer

Connected to XADC VP/VN pins. Range: 0% = 0 km/h → 100% = 99 km/h.
Speed displayed on 7-segment display. Controls AI accelerator thresholds.

### LEDs

| LED | Condition |
|---|---|
| LED0 | System active — always ON after programming |
| LED1 | Pedestrian detected AND SW0=ON |
| LED2 | Lane warning AND SW1=ON |
| LED3 | Traffic sign detected AND SW2=ON |
| LED4 | Collision warning AND SW3=ON (`emergency_state`) |
| LED5 | Brake authorized (SW6=ON + `emergency_brake`) |

### 7-Segment Display

Shows vehicle speed 00–99 from potentiometer. Active-LOW segments, `seg[7:0]` (`seg[7]` = DP, always OFF).

### Key XDC Pin Assignments

| Signal | Pin |
|---|---|
| `clk` | F14 |
| `btn0` | J2 |
| `btn2` | H2 |
| `btn3` | J1 |
| `sw0–sw3` | V2, U2, U1, T2 |
| `sw_lane_sev[1:0]` | R2, T1 |
| `sw6` | R1 |
| `led0–led5` | G1, G2, F1, F2, E1, E2 |
| `uart_rx` | V12 |
| `uart_tx` | U11 |
| `seg[7]` (DP) | A6 |
| `an[3:0]` | A8, C7, C4, D5 |

---

## Hardware Test Quick Reference

### Before Every Test

```
1. Program bitstream → LED0 turns ON
2. Set switches for the scenario
3. Rotate potentiometer to desired speed (read on 7-seg)
4. Press BTN0 once
5. Run:  python main.py
6. Press SPACE to load image
```

### After Every Scenario

```
Press R in Python  →  then press BTN3 on the board
```

### Scenario Switch Settings

| Scenario | Switches | Speed |
|---|---|---|
| Pedestrian | SW0=ON, SW3=ON, SW6=ON | > 60 km/h |
| Lane Departure | SW1=ON, SW3=ON, SW4=ON, SW5=ON | > 60 km/h |
| Traffic Sign | SW2=ON, SW3=ON | > 40 km/h |
| Obstacle / Collision | SW3=ON, SW6=ON | > 60 km/h |
| Full Demo | All switches ON | ≥ 70 km/h |

> Board demo photos and UART terminal screenshots: `docs/images/board/`

![Board Overview](docs/images/board/board_overview.png)
![UART Terminal](docs/images/board/uart_terminal.png)

---

## Known Issues and Fixes

| # | Issue | Fix Applied |
|---|---|---|
| 1 | `uart_rx.v` — two always blocks driving `valid_hold_cnt` (multi-driver) | Merged into single always block handling both trigger and countdown |
| 2 | `top.v` — `xadc_wiz_0` IP missing caused red error icon | Removed instantiation; `xadc_data` kept as direct port; XADC reads internally in `supporter_module.v` |
| 3 | `top.xdc` — `rst_n` and `xadc_data[11:5]` unconstrained (DRC error) | `rst_n` removed from design; `xadc_data` handled inside module |
| 4 | `riscv_control_unit.v` — FSM returned to IDLE after DONE | Changed to return to `WAIT_UART` for continuous Python sends |
| 5 | `sensor_fusion.v` — `emergency_state` auto-cleared on condition drop | Changed to sticky latch; clears only on explicit reset |
| 6 | `security_unit.v` — `brake_authorized` needed 3 FSM cycles to assert | Now asserts immediately in VERIFY state same cycle as `emergency_brake` |
| 7 | `combined_tb.v` — `send_pkt` task used `p[0]`,`l[0]` indexing on scalars | Changed to use scalar directly: `{4'b0, o, s, l, p}` |
| 8 | `combined_tb.v` — `uart_rx_initial` named begin block syntax error | Changed to simple `#100` delay |
| 9 | `btn1_db` — declared but never used | Removed `debouncer u_db1` and `btn1_db` wire from `top.v` |
| 10 | `ai_accelerator.v` — `emergency_trigger` port missing from `top.v` | Added `.emergency_trigger(btn2_db)` to `u_ai` instantiation in `top.v` |

---

## Setup and Usage

### FPGA Flow (Vivado)

```tcl
# In Vivado Tcl Console
source fpga/scripts/vivado_build.tcl
```

Or open Vivado GUI → create project → add all RTL files from `rtl/` → add `fpga/constraints/top.xdc` → Run Implementation → Generate Bitstream → Program Device.

### Cadence Simulation (NCLaunch)

```bash
# Using filelist
ncvlog -f sim/filelist/rtl_nclaunch.f
ncelab combined_tb
ncsim combined_tb
```

### Cadence Genus Synthesis

```tcl
# In Genus shell
source synthesis/genus/scripts/script.tcl
```

### Cadence Innovus Place & Route

```tcl
# In Innovus shell
source synthesis/innovus/scripts/run_pnr.tcl
```

### Python Setup

```bash
# Install dependencies
pip install ultralytics opencv-python pyserial numpy

# Edit serial port in config.py
# Linux: /dev/ttyUSB0   Windows: COM3

# Run without FPGA
python python/test_no_fpga.py

# Run with FPGA
python python/main.py
```

---

*Developed by Hariharan Ganesh, Kamalesh S  — Saveetha Engineering College*
