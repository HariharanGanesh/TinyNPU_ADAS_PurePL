# The Grand Project Workflow: From AI to Silicon

Building a custom AI accelerator from scratch requires integrating three completely different engineering disciplines: **Machine Learning**, **Hardware Engineering (RTL)**, and **Embedded Software (Firmware)**. 

Here is the exact step-by-step lifecycle of how this ADAS project comes to life.

---

## Phase 1: The Machine Learning (Python & PyTorch)
*Goal: Teach the AI how to detect cars and prepare its brain for the hardware.*

1. **Design & Train:** You write your neural network architecture (`tinyvelocity.py`) in PyTorch and train it on a PC using thousands of images of cars. The result is a heavy, floating-point `.pth` checkpoint.
2. **Quantization & Export:** FPGAs don't like heavy decimal math. You run the `export_fpga_weights.py` script to squeeze those heavy floating-point weights down into tiny `INT8` whole numbers.
3. **The Output:** The script spits out a C-code file called `tinyvelocity_weights.h`. The ML Engineer's job is now done!

---

## Phase 2: The Hardware Engineering (Verilog & Vivado)
*Goal: Build the physical "muscles" (the silicon calculator) to run the AI fast.*

1. **RTL Design:** We write Verilog code (`processing_element.v`, `systolic_array.v`) to create the TinyNPU—a massive grid of 160 multipliers designed specifically to crunch the `INT8` math from Phase 1.
2. **System Integration:** In Vivado, we wire the NPU to a RISC-V processor (the brain), an AXI DMA (the data transporter), and the `dvi2rgb` HDMI IP (the eyes).
3. **Synthesis & Bitstream:** Vivado spends 30 minutes figuring out how to map all of this logic onto the physical microscopic transistors inside the Zynq-7020 chip.
4. **The Output:** Vivado generates `npu_system_wrapper.bit`. The Hardware Engineer's job is done!

---

## Phase 3: The Embedded Software (C Firmware)
*Goal: Give the RISC-V processor the "brain" it needs to orchestrate the hardware.*

1. **Write the Logic:** We write a `main.c` file for the RISC-V processor. This code says: *"Wait for a video frame, tell the DMA to send the weights to the NPU, and then draw a bounding box where the NPU found a car."*
2. **Import the AI:** At the top of `main.c`, we type `#include "tinyvelocity_weights.h"`. This permanently embeds the AI's knowledge (from Phase 1) directly into the software.
3. **Compile:** We compile the C code using a RISC-V compiler. 
4. **The Output:** The compiler generates a machine-code file called `firmware.hex`. The Software Engineer's job is done!

---

## Phase 4: The Final Integration & Deployment
*Goal: Put it all together and turn it on.*

1. **Bake the Brain:** We take the `firmware.hex` from Phase 3 and tell Vivado to bake it permanently into the FPGA's internal memory (BRAM) inside the `.bit` file from Phase 2.
2. **Flash the Board:** You plug the PYNQ-Z2 board into your computer and click "Program Device" in Vivado.
3. **Execution:**
   * The silicon instantly configures itself into a 160-MAC NPU and a RISC-V processor.
   * The RISC-V processor wakes up, reads the `firmware.hex` code, and starts looping.
   * The HDMI IN port receives live video from your camera.
   * The RISC-V processor pumps the video frames and the `tinyvelocity_weights.h` into the NPU.
   * The NPU spits out the location of the cars.
   * The RISC-V processor draws a green box on the video feed and shoots it out the HDMI OUT port to your monitor!
