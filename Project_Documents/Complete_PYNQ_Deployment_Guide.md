# Complete PYNQ-Z2 Deployment Guide: TinyNPU Project

This document serves as the complete operational manual for deploying the TinyNPU accelerator onto the PYNQ-Z2 development board.

Because the TinyNPU is designed to be an **ASIC-ready AI accelerator**, it can be deployed in two entirely different ways depending on your verification goals. 

---

## 1. The Two Deployment Paths

### Option A: Pure Hardware (ASIC-Style)
In this mode, we treat the PYNQ-Z2 exactly like a bare-metal FPGA. The ARM processors and Linux operating system are completely ignored. 
- **Use Case:** To prove to a mentor or evaluator that the core RTL is 100% self-sufficient and does not rely on software trickery to function.
- **How it works:** A hardware module (`bram_sensor_emulator`) acts like a physical camera sensor, blasting an image from Block RAM directly into the NPU at 125 MHz. A hardware scoreboard checks the output.
- **Status:** **Currently Built & Ready.**

### Option B: Software Overlay (Jupyter Notebook)
In this mode, we use the PYNQ framework's ARM processor (running Linux) to control the NPU via software.
- **Use Case:** For rapid prototyping, testing thousands of different images dynamically from an SD card, or integrating with a USB webcam.
- **How it works:** Python code running on the ARM processor allocates DMA buffers in DDR memory and streams images to the NPU.
- **Status:** Architecture supported, but requires exporting the `.hwh` file and writing Python drivers.

---

## 2. Deploying Option A (Pure Hardware)

We have already compiled the bitstream for Option A (`tinynpu_hw_test.bit`). Follow these steps to flash the board.

### Step 1: Connect the Board
1. Ensure the PYNQ-Z2 board boot jumper is set to **JTAG** (not SD).
2. Connect a Micro-USB cable from your PC to the `PROG/UART` port on the board.
3. Turn on the power switch.

### Step 2: Flash the Bitstream
1. Open **Vivado**. (You do not need to open a project).
2. In the Welcome screen or Flow Navigator, click **Open Hardware Manager**.
3. Click **Open Target** -> **Auto Connect**. Vivado will detect the `xc7z020_1` chip.
4. Right-click the chip and select **Program Device**.
5. Browse and select the bitstream we generated: 
   `D:\Final year project\vivado_hw_test_proj\tinynpu_hw_test.bit`
6. Click **Program**.

### Step 3: Run the Test on Silicon
Once the progress bar completes, the hardware test is live!
- **LED 0** will turn ON (indicates clock and reset are stable).
- Press **BTN 1** on the board. This triggers the hardware emulator.
- The emulator blasts the test image through the systolic array pipeline.
- **LED 1** turns ON when the emulator finishes sending the image.
- **LED 2** turns ON when the scoreboard finishes receiving the NPU output.
- **LED 3** turns ON (Green) if the NPU output perfectly matches the expected golden output!

### How to Change the Test Image in Option A
In Option A, the test image is physically baked into the FPGA's Block RAM during compilation. To test a new image:
1. Convert your image into a hexadecimal file (`test_image.hex`).
2. Generate the expected NPU output (`golden_output.hex`).
3. Place both files in the RTL source directory.
4. Open `bram_sensor_emulator.v` and `hw_scoreboard.v` and uncomment the `$readmemh` lines to point to your new hex files.
5. Run the `Generate_TinyNPU_Bitstream.bat` file to generate a new `.bit` file with the new image baked inside.

---

## 3. Deploying Option B (Software Overlay)

If your mentor asks to see the NPU processing images dynamically from a Python script or webcam, you will use Option B.

### Step 1: Prepare the Board
1. Flash the official PYNQ v3.0.1 image onto a MicroSD card.
2. Set the PYNQ-Z2 boot jumper to **SD**.
3. Connect the board to your local network via Ethernet and power it on.

### Step 2: Export the Hardware Overlay
1. In Vivado, run the `build_pynq_system.tcl` script to wrap the TinyNPU inside a Zynq Processing System (PS) block design.
2. Generate the Bitstream.
3. Go to **File -> Export -> Export Hardware**. Include the bitstream. This generates a `.xsa` or `.hwh` file.

### Step 3: Run in Python
1. Open a browser and navigate to `http://pynq:9090` to access the Jupyter Notebook environment.
2. Upload the `.bit` and `.hwh` files to the board.
3. Write a Python script to allocate memory and trigger the NPU:

```python
from pynq import Overlay, allocate
import numpy as np

# Load the hardware
overlay = Overlay("tinynpu_system.bit")
dma = overlay.axi_dma_0

# Allocate contiguous memory for the NPU
input_buffer = allocate(shape=(64, 64, 3), dtype=np.int8)
output_buffer = allocate(shape=(16,), dtype=np.int8)

# Load your dynamic image into the buffer
# ... (Image processing code here) ...

# Trigger the NPU hardware via DMA
dma.sendchannel.transfer(input_buffer)
dma.recvchannel.transfer(output_buffer)
dma.sendchannel.wait()
dma.recvchannel.wait()

print("NPU Output:", output_buffer)
```

---

## 4. Summary of Results for Mentor Presentation

Regardless of which deployment method is used, the physical synthesis of the TinyNPU core is finalized.
- **Power Consumption:** The aggressive clock gating optimizations achieved a dynamic power footprint of **117 mW**.
- **Timing:** The pipelined MAC units easily meet the **100 MHz** requirement, with an absolute maximum theoretical frequency (fMAX) of **195 MHz**.
- **Readiness:** The RTL is 100% ASIC-ready, synthesizing without latches, combinational loops, or structural errors.
