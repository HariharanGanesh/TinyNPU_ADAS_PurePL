# TinyNPU ADAS (Pure PL) - Quickstart Guide

This guide provides step-by-step instructions on how to clone, build, and run the TinyNPU Advanced Driver Assistance System (ADAS) project on a PYNQ-Z2 FPGA board.

## 📋 Prerequisites

### Hardware Requirements
* **FPGA Board:** PYNQ-Z2 (Zynq-7020, `xc7z020clg400-1`)
* **Video Source:** Laptop, Raspberry Pi, or Camera with HDMI Output (Set to 720p resolution)
* **Video Display:** Monitor or TV with HDMI Input
* **Cables:** 2x HDMI cables, 1x Micro-USB cable (for Power/JTAG)

### Software Requirements
* **Vivado Design Suite:** Version 2025.1 (Required for IP compatibility)
* **Git:** To clone the repository

---

## 🚀 Step 1: Clone the Repository

Open your terminal or command prompt and clone the project to your local machine:

```bash
git clone https://github.com/HariharanGanesh/TinyNPU_ADAS_PurePL.git
cd TinyNPU_ADAS_PurePL
```

*Note: It is highly recommended to clone the repository to a short path on your Windows machine (e.g., `D:\TinyNPU`) to avoid Vivado's 260-character path limit errors during synthesis.*

---

## 🛠️ Step 2: Open the Project in Vivado

1. Launch **Vivado 2025.1**.
2. From the Quick Start menu, click **Open Project**.
3. Navigate to the cloned repository and select the Vivado project file:
   `RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr`
4. Click **OK**.

Vivado will automatically load the Block Design (`npu_system.bd`), the custom TinyNPU IPs, and the constraints file (`tinynpu_master.xdc`).

---

## ⚙️ Step 3: Generate the Bitstream

The project is already fully constrained and optimized to meet timing at 125/195 MHz. You can generate the bitstream directly.

1. In the Flow Navigator (left panel), click on **Generate Bitstream**.
2. Vivado will prompt you to run Synthesis and Implementation first. Click **Yes**.
3. Choose your preferred number of CPU jobs and click **OK**.
4. Wait for the process to complete (this typically takes 15-30 minutes depending on your PC).

*Note: You may see a few standard warnings about unconnected IP ports (`[Synth 8-7071]`) or a BUFG-BUFG placement override (`[Place 30-120]`). These are expected and safely bypassed.*

---

## 🔌 Step 4: Hardware Setup

1. **Power & Programming:** Connect the Micro-USB cable from your PC to the `PROG/UART` port on the PYNQ-Z2.
2. **Video Input:** Connect your HDMI video source (Laptop/Camera) to the **HDMI IN** port on the PYNQ-Z2.
   * *Important:* Ensure your source is outputting a **1280x720 (720p) @ 60Hz** signal.
3. **Video Output:** Connect the **HDMI OUT** port on the PYNQ-Z2 to your monitor.
4. **Power On:** Flip the power switch on the PYNQ-Z2 to turn it on.

---

## 💻 Step 5: Program the FPGA

1. In Vivado, open the **Hardware Manager** (bottom of the Flow Navigator).
2. Click **Open Target** > **Auto Connect**.
3. Once the board is detected, right-click `xc7z020_1` (or similar) and select **Program Device**.
4. The bitstream file should automatically point to:
   `RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.runs/impl_1/npu_system_wrapper.bit`
5. Click **Program**.

---

## 🎯 Step 6: Expected Results

Once the FPGA is programmed, the TinyNPU will immediately begin processing the video stream entirely in Programmable Logic (PL):

* **Monitor Output:** You will see the live video feed passed through to the monitor, overlaid with hardware-drawn bounding boxes around detected objects (e.g., pedestrians, vehicles).
* **ADAS Warnings (LEDs):** The PicoRV32 safety controller evaluates the TinyNPU detections and controls the PYNQ-Z2's onboard LEDs:
  * **LD0:** Pedestrian Warning
  * **LD1:** Lane Departure Warning
  * **LD2:** Traffic Sign Warning
  * **LD3:** Emergency Brake Authorized (Critical Hazard)

### Troubleshooting
* **No Video Output?** Ensure your source is strictly set to 720p. The Digilent HDMI IPs in this project are configured for a 74.25 MHz pixel clock.
* **IP Not Found Errors?** Ensure the `IP/` and `Shared/IP/` folders are present in your cloned repository. If Vivado complains about missing IPs, go to *Settings > IP > Repository* and ensure both paths are listed.
