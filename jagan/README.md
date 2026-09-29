# 🧠 TinyNPU200 Full PL - Deep Learning Accelerator Package

Welcome to the **TinyNPU200 Full PL Deployment Package** for the **PYNQ-Z2 FPGA** board (`xc7z020clg400-1`).

This project implements a **100% Programmable Logic (Full PL)** real-time neural network accelerator with **720p@60Hz HDMI video processing**, controlled entirely via **JTAG-to-AXI Master** (no ARM PS CPU required).

---

## 📂 Directory Structure

```
jagan/
├── README.md                          <-- You are here! (Complete User Guide)
├── rtl/                               <-- Complete Verilog-2001 Source Files
│   ├── pe/                            │   └── processing_element.v (3-stage MAC PE)
│   ├── systolic_array/                │   └── systolic_array.v (20x8 INT8 array, 160 PEs)
│   ├── activation/                    │   ├── activation_unit.v (LeakyReLU, HardSwish)
│   │                                  │   └── hardswish_lut.v (256-entry INT8 LUT)
│   ├── pooling/                       │   └── pooling_unit.v (2x2 MaxPool & AvgPool)
│   ├── buffers/                       │   ├── weight_buffer.v (Dual-bank BRAM)
│   │                                  │   ├── activation_buffer.v
│   │                                  │   ├── output_buffer.v
│   │                                  │   └── cdc_async_fifo.v (195MHz -> 74.25MHz CDC)
│   ├── axi/                           │   └── axi4_lite_slave.v (Control CSRs)
│   ├── clocking/                      │   └── pixel_pll.v (74.25 MHz MMCM)
│   └── control/                       │   ├── npu_controller.v (FSM with Spatial Tiling)
│                                      │   ├── tinynpu_top.v & helper modules
├── constraints/                       <-- Physical FPGA Pin Mappings
│   └── hdmi_pins.xdc                  │   └── PYNQ-Z2 Master XDC (HDMI RX/TX, Clocks)
├── ip_repo/                           <-- Packaged Vivado IP Cores
│   ├── NPU300PM/                      │   └── TinyNPU200 Core IP
│   └── digilent-vivado-library/       │   └── Digilent HDMI dvi2rgb & rgb2dvi IP
├── scripts/                           <-- Tcl Automation Scripts
│   ├── build_project.tcl              │   └── Recreates full Vivado project
│   ├── fix_all_errors.tcl             │   └── Synthesizes, routes & writes .bit file
│   └── run_inference_jtag.tcl         │   └── JTAG AXI hardware execution script
└── data/                              <-- Memory Initialization Files
    └── dummy_weights.hex              │   └── Preloaded INT8 model weights
```

---

## ⚡ Key Hardware Specifications

- **Device:** Xilinx Zynq-7020 (`xc7z020clg400-1`) on PYNQ-Z2 Board
- **Systolic Array:** $20 \times 8$ Weight-Stationary Matrix (160 PEs)
- **Peak Performance:** ~25 GOPS (INT8 precision at 195 MHz compute clock)
- **Supported Activations:** ReLU, Identity, ReLU6, LeakyReLU ($\alpha=0.125$), HardSwish
- **Supported Pooling:** 2x2 MaxPool, 2x2 AvgPool
- **Video Output:** 720p @ 60Hz Live HDMI Video stream via onboard TMDS transmitter

---

## ⚙️ Prerequisites & Setup

1. **Software:** Xilinx Vivado (v2020.2 or higher, tested on Vivado 2025.1).
2. **Hardware:**
   - **PYNQ-Z2 FPGA Board**
   - **12V 3A DC Power Supply** plugged into the barrel jack *(Mandatory: 5V USB power cannot drive the onboard HDMI TMDS transmitter chip)*.
   - **Micro-USB Cable** connected to the `PROG/UART` USB port.
   - **HDMI Cable** connected from PYNQ-Z2 `HDMI OUT` to a projector or monitor.

---

## 🚀 Step-by-Step Execution Guide

### Step 1: Open Vivado & Build Project
1. Launch **Xilinx Vivado**.
2. Open the **Tcl Console** at the bottom of Vivado.
3. Recreate the project by running:
   ```tcl
   source {D:/Final year project/jagan/scripts/build_project.tcl}
   ```

### Step 2: Synthesize & Generate Bitstream
Run the automated build script to configure MMCM clocks, check XDC constraints, and generate the bitstream:
```tcl
source {D:/Final year project/jagan/scripts/fix_all_errors.tcl}
```
*Expected Output:* Generates `npu_system_wrapper.bit` under `npu200_project/npu200_project.runs/impl_1/`.

---

### Step 3: Program PYNQ-Z2 Board
1. Turn ON the PYNQ-Z2 board with the **12V power supply** plugged in.
2. In Vivado, click **Open Hardware Manager** -> **Auto Connect**.
3. Right-click target `xc7z020_0` -> **Program Device**.
4. Select Bitstream File:
   `D:/Final year project/jagan/npu200_project/npu200_project.runs/impl_1/npu_system_wrapper.bit`
5. Click **Program**. Verify the **DONE LED** on the board lights up solid green.

---

### Step 4: Run Live NPU Hardware Inference via JTAG
In the Vivado Tcl Console, execute the JTAG control script:
```tcl
source {D:/Final year project/jagan/scripts/run_inference_jtag.tcl}
```

**What this script does:**
1. Configures VTC (Video Timing Controller) over AXI-Lite (`0x44A00000`) for 720p@60Hz timing.
2. Reads NPU hardware version & feature registers at `0x40000078`.
3. Sets activation mode to **LeakyReLU** and pooling mode to **2x2 MaxPool**.
4. Preloads INT8 model weights into BRAM Port A (`0xC0000000`).
5. Triggers TinyNPU matrix execution (`0x40000000 = 1`).
6. Displays the real-time processed video stream on your HDMI projector/monitor!

---

## 🗺️ Memory & Register Address Map

| Address Range | Component / Subsystem | Description |
| :--- | :--- | :--- |
| `0x40000000` | NPU Control Register (CSR) | Write `1` to start NPU execution |
| `0x40000054` | Activation Select (REG_ACT_EXT) | `0`=ReLU, `1`=ID, `2`=ReLU6, `3`=LeakyReLU, `4`=HardSwish |
| `0x40000058` | Pooling Mode (REG_POOL_MODE) | `0`=Bypass, `1`=2x2 MaxPool, `2`=2x2 AvgPool |
| `0x40000078` | NPU Hardware Version | Read-Only: Returns `0x02000001` |
| `0x4000007C` | NPU Feature Bitmask | Read-Only capability flags |
| `0x44A00000` | VTC Video Timing Controller | Write `1` to enable 720p timing generator |
| `0xC0000000` | Weight BRAM Port A | Dual-port AXI BRAM interface for weight preloading |

---

## 💬 Support & Troubleshooting
- **No HDMI Display Output:** Make sure the **12V DC barrel jack** is plugged in. USB 5V alone does not power the HDMI output transmitter.
- **Hardware Master Not Found:** Ensure `run_inference_jtag.tcl` is executed AFTER programming `npu_system_wrapper.bit`.

Enjoy experimenting with **TinyNPU200**! 🎉
