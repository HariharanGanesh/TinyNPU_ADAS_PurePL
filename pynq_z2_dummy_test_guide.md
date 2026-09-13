# PYNQ-Z2 Deployment Guide: Dummy Weight Video Loopback Test

This guide covers how to deploy the synthesized ADAS bitstream to your PYNQ-Z2 board to verify the HDMI video pipeline (HDMI RX -> NPU -> HDMI TX + Overlay) without needing a real trained model yet.

Because the NPU BRAMs are initialized with zeros (or random noise) instead of real weights, the neural network will output chaotic logits. The `streaming_topk` and `bbox_decoder_dfl` hardware will dutifully decode this noise into random, jittery bounding boxes, which the RISC-V firmware will draw onto the HDMI output. This is a perfect way to verify the entire data path!

## Step 1: Gather the Files
From your PC (where Vivado ran), you need three files:
1.  **Bitstream (`.bit`)**: Located at `D:\Final year project\RISCV_ADAS_PURE_PL\RISCV_ADAS_PURE_PL.runs\impl_1\npu_system_wrapper.bit`
2.  **Hardware Handoff (`.hwh`)**: Located at `D:\Final year project\RISCV_ADAS_PURE_PL\RISCV_ADAS_PURE_PL.gen\sources_1\bd\npu_system\hw_handoff\npu_system.hwh`
3.  *(Optional)* If you need to reload the RISC-V firmware without rebuilding the bitstream, grab the `firmware.hex` from `D:\Final year project\IP\RISCV_ADAS_Controller\sw\firmware.hex`

*Note: Rename the bitstream and the `.hwh` file to have the exact same base name (e.g., `adas_npu.bit` and `adas_npu.hwh`).*

## Step 2: Hardware Setup
1.  **Power & Boot:** Ensure your PYNQ-Z2 board is plugged in, set to boot from the SD card (containing the PYNQ image), and powered on.
2.  **Network:** Connect the board to your local network via Ethernet (or use the micro-USB for local network access).
3.  **HDMI IN:** Connect an HDMI cable from a video source (e.g., a laptop outputting 1080p or 720p 60Hz, or a Raspberry Pi) to the **HDMI RX** port on the PYNQ-Z2.
4.  **HDMI OUT:** Connect an HDMI cable from the **HDMI TX** port on the PYNQ-Z2 to a monitor.

## Step 3: Upload to PYNQ Jupyter Notebook
1.  Open your browser and navigate to `http://pynq:9090` (or the IP address of your board).
2.  Log in (default password is `xilinx`).
3.  Create a new folder (e.g., `adas_test`).
4.  Upload `adas_npu.bit` and `adas_npu.hwh` into this folder.

## Step 4: Python Overlay Script
Create a new Jupyter Notebook inside the `adas_test` folder and run the following Python code to configure the Zynq Processing System (PS) clocks and load the pure-PL bitstream:

```python
from pynq import Overlay
import time

print("Loading ADAS Bitstream...")
# Load the overlay. This configures the FPGA fabric.
overlay = Overlay("adas_npu.bit")

# The PYNQ-Z2 HDMI IP (dvi2rgb/rgb2dvi) requires the Zynq PS to provide FCLK0 
# as a reference clock (usually 100MHz or 200MHz) depending on the Clocking Wizard setup.
# If your design uses 'sysclk' mapped to the 125MHz board pin (H16), 
# then the overlay load is sufficient.

print("Bitstream loaded. RISC-V should now be booting from BRAM.")
print("Observe the LEDs on the board and the HDMI Monitor.")
```

## Step 5: What to Expect (Verification)
Once the cell executes:
1.  **Monitor Output:** The monitor should lock onto the video signal from your laptop. You should see the laptop's screen passed through.
2.  **Bounding Boxes:** Because the RISC-V is running and reading from the NPU (which is processing dummy/noise weights), you will see jittery, randomly colored bounding boxes flickering aggressively over the video feed.
3.  **ADAS Safety LEDs:** The four ADAS safety LEDs (Pins R14, P14, N16, M14) should be flickering wildly as the chaotic classes randomly trigger the Pedestrian, Lane, and Traffic Sign warning thresholds in the firmware.

### Troubleshooting
*   **Black Screen:** Ensure the input video is exactly 720p or 1080p (depending on what you configured the Digilent HDMI IPs for in Vivado). Some laptops default to weird resolutions when plugged into a raw FPGA sink. Force the resolution in Windows Display Settings.
*   **No Boxes but Video Works:** The RISC-V firmware might be stuck in reset, or the NPU pipeline is stalled. Check if the `ext_reset` (BTN0) is pressed or needs to be toggled. Press BTN0 to reset the RISC-V.
