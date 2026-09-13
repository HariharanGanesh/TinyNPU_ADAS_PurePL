# FPGA Hardware Testing Guide: Detailed Physical Deployment

This guide outlines the extremely detailed, physical step-by-step procedures to deploy and verify the data flow of your two hardware architectures on the PYNQ-Z2 board. It covers everything from physical cable connections to the final terminal output.

---

## Part 1: Physical Board Preparation (PYNQ-Z2)

Before testing either architecture, you must physically connect the board to your PC.

1. **Power Supply:** Set the Power Jumper (JP5) to `USB` if powering from your PC, or `REG` if using an external 12V adapter.
2. **PROG / UART Port:** Plug a Micro-USB cable into the port labeled **PROG/UART** (near the power switch) and connect the other end to your PC. 
   - *Why:* This single cable serves two massive purposes: it acts as the **JTAG interface** (so Vivado can flash the bitstream) AND it acts as the **Serial Console** (so the RISC-V processor can print text to your screen).
3. **Ethernet Port:** Plug an Ethernet cable from the board to your PC or router.
   - *Why:* This is **only** required for Architecture 1 to access the Jupyter Notebooks. Architecture 2 (Pure PL) does not use Ethernet.
4. **Power Switch:** Flip the switch to turn the board ON.

---

## Architecture 1: TinyNPU300PM (Zynq ARM + PYNQ Workflow)
*This architecture runs a full Linux OS on the ARM processor. You will interact with it using Python over the network.*

### Step 1: Boot Configuration
* **Boot Jumper:** Ensure the Boot Jumper (JP4) is set to **SD**.
* **SD Card:** Insert your MicroSD card containing the PYNQ v2.x image.
* **Boot:** Power on the board. Wait about 60 seconds until the **DONE** LED and the colored LEDs flash, indicating Linux has fully booted.

### Step 2: Upload the Hardware Files
1. Open your web browser on your PC and navigate to `http://192.168.2.99` (or `http://pynq`).
2. Log into the Jupyter Notebook interface (password: `xilinx`).
3. Click the **Upload** button in the top right.
4. Upload **both** your `.bit` file and the corresponding `.hwh` file (Hardware Handoff) into the same folder. *Make sure they have the exact same name (e.g., `tinynpu.bit` and `tinynpu.hwh`).*

### Step 3: Write and Execute the Python Test
1. Create a new Python 3 Jupyter Notebook.
2. Type the following code into the cell to allocate the contiguous physical memory buffers required by the NPU's DMA:
   ```python
   from pynq import Overlay, allocate
   import numpy as np

   # 1. Load the Bitstream into the FPGA fabric
   overlay = Overlay("tinynpu.bit")
   dma = overlay.axi_dma_0

   # 2. Allocate contiguous memory in DDR RAM
   weights = allocate(shape=(4096,), dtype=np.int8)
   activations = allocate(shape=(4096,), dtype=np.int8)
   output = allocate(shape=(1024,), dtype=np.int32)

   # 3. Fill inputs with the 1-valued dummy data
   weights[:] = 1
   activations[:] = 1

   # 4. Fire the DMA across the AXI Bus
   dma.sendchannel.transfer(activations) 
   dma.recvchannel.transfer(output)      
   
   # 5. Wait for the NPU to finish computing
   dma.sendchannel.wait()
   dma.recvchannel.wait()
   
   print("NPU Output Data:")
   print(output)
   ```
3. **Expected Output:** Press `Shift + Enter` to run the cell. The output array printed on your screen should be filled with exact multiples of your kernel size (e.g., an array of exactly `9`s for a $3\times3$ convolution).

---

## Architecture 2: RISCV_ADAS_NPU300 (Pure PL Bare-metal Workflow)
*This is the architecture we just built. The ARM processor is disabled. A soft RISC-V processor lives completely inside the FPGA fabric.*

### Step 1: Boot Configuration
* **Boot Jumper:** Change the Boot Jumper (JP4) to **JTAG**.
* **SD Card:** Remove the SD card (it is completely ignored in this mode).
* **Boot:** Power on the board. The board will appear "dead" (no lights) because the FPGA fabric is currently blank.

### Step 2: Setup the Serial Monitor (PC Side)
*Because there is no Python or Linux, the RISC-V processor will communicate by beaming raw text over the PROG Micro-USB cable.*
1. On your Windows PC, open **Device Manager** and expand **Ports (COM & LPT)**. Look for "USB Serial Port (COMx)" and note the COM number (e.g., `COM4`).
2. Open a Serial Terminal program like **TeraTerm** or **PuTTY**.
3. Select **Serial** connection, and enter your COM port.
4. Go to **Setup -> Serial Port** and configure it exactly like this:
   * **Baud Rate:** `115200`
   * **Data:** `8 bit`
   * **Parity:** `none`
   * **Stop:** `1 bit`
   * **Flow Control:** `none`

### Step 3: Flash the Bitstream via Vivado
1. Open **Vivado** on your PC.
2. At the bottom of the Flow Navigator on the left, click **Open Hardware Manager**.
3. Click **Open Target -> Auto Connect**. Vivado will detect the PYNQ-Z2 board over the Micro-USB cable.
4. Click **Program Device** and select the `npu_system_wrapper.bit` file we compiled today.
5. Click **Program**.
6. **Hardware Check:** The blue **DONE** LED on the PYNQ-Z2 will instantly light up. This means the NPU and the RISC-V processor have successfully materialized on the silicon.

### Step 4: Verify the Data Flow Output
1. The microsecond the blue DONE LED lights up, the RISC-V processor boots from its internal BRAM and begins executing the C firmware (which contains your `dummy_data.h` arrays).
2. Look at your TeraTerm/PuTTY window! You will see the `printf()` statements from the RISC-V C code streaming across the screen.
3. **Expected Output:** You should see text similar to:
   ```text
   [RISC-V] Booting TinyNPU ADAS System...
   [RISC-V] Starting DMA Data Flow Verification...
   [RISC-V] NPU Output Results:
   9, 9, 9, 9, 9, 9, 9, 9...
   [RISC-V] Hardware Verification Complete.
   ```
4. If you missed the text, simply press the **SRST** (System Reset) physical button on the PYNQ-Z2 board. This will reboot the RISC-V processor and print the text to your screen again.

---

## Part 3: HDMI Monitor Video Verification

Because this ADAS system is designed to process live video, you can physically verify that the hardware is outputting a valid video signal by connecting it to a real monitor!

### Step 1: Physical Cable Connections
1. **HDMI OUT (To Monitor):** Plug an HDMI cable into the **HDMI OUT** port of the PYNQ-Z2 (this is the port closest to the Ethernet jack). Plug the other end into your desktop monitor or TV.
2. **HDMI IN (Camera/Laptop):** Plug a second HDMI cable into the **HDMI IN** port of the PYNQ-Z2 (closest to the USB ports). Plug the other end into a video source, such as a laptop or a Raspberry Pi camera outputting 720p or 1080p video.
   * **Why:** The FPGA's internal video pipeline (the Digilent `dvi2rgb` IP) expects a live video stream to process. If you don't connect a source to HDMI IN, the HDMI OUT might just display a black screen or a "No Signal" message.

### Step 2: Power and Flash
1. Power on your external monitor and ensure it is set to the correct HDMI input channel.
2. Power on the PYNQ-Z2 board.
3. Flash the `npu_system_wrapper.bit` bitstream using Vivado Hardware Manager (exactly as described in Architecture 2).

### Step 3: Verify the Visual Output
* **What to expect:** The microsecond the bitstream flashes (when the blue DONE LED lights up), the FPGA's video pipeline activates.
* **The Result:** You should see the video feed from your laptop/camera passing straight through the FPGA and displaying on your external monitor! 
* **If the NPU is running:** If your RISC-V firmware is actively running the ADAS deep learning model on the video frames, you will literally see the **Hardware Bounding Boxes** being drawn over the cars/objects on the monitor in real-time. 

> [!TIP]
> If your monitor says "Out of Range" or flashes black, ensure your laptop/camera is outputting a standard resolution (like `1280x720 @ 60Hz` or `1920x1080 @ 60Hz`), as the Digilent IP is highly sensitive to non-standard resolutions.
