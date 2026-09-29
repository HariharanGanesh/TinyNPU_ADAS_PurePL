# Ballistic Vision NPU300PM — System Architecture & AI Developer Specification

This document serves as the complete technical handoff for the Deep Learning (DL) engineering team and provides a comprehensive breakdown of the physical hardware architecture deployed on the PYNQ-Z2 FPGA.

---

## PART 1: Deep Learning Hardware Specifications

### 1.1 Hardware At A Glance (NPU300PM / TinyNPU200JPMAX)
| Parameter                    | Value                            |
|------------------------------|----------------------------------|
| Target Board                 | PYNQ-Z2 (Xilinx Zynq-7020)       |
| NPU Clock Frequency          | 125 MHz                          |
| Systolic Array Topology      | **26 rows × 8 columns**          |
| Total Processing Elements    | **208 INT8 MACs** (DSP-Accelerated) |
| Peak Compute Throughput      | **52.0 GOPS (0.052 TOPS)**       |
| Target Application           | Drone Tracking up to **~65 m/s** |
| Target Host API              | PYNQ Python (Jupyter Notebook)   |

### 1.2 Model Constraints & Quantization
> [!IMPORTANT]
> The hardware **only supports INT8 arithmetic**. Models must undergo Quantization-Aware Training (QAT) to map weights and activations to the `[-128, 127]` range. Standard FP32 or FP16 models will fail to load.

- **Weight/Activation Precision**: INT8 (signed)
- **Bias Precision**: INT32 (BatchNorm must be fused into the bias offline)
- **Requantization**: Per-channel scale (M0) and right-shift (n)
- **Parameter Limit**: Total model parameters must stay under **10 MB**.
- **Channel Granularity**: Channel counts **must be multiples of 8**. The 26-row array consumes up to 26 channels simultaneously per cycle.

### 1.3 Supported Neural Network Operators
If an operator is not on this list, the hardware cannot execute it. You must map it to the ARM CPU (which is slow).

| Operator                      | Hardware Supported? | Notes                                          |
|-------------------------------|---------------------|------------------------------------------------|
| Depthwise Convolution (3×3)   | ✅ Yes               | Hardware line buffers built-in                 |
| Pointwise Convolution (1×1)   | ✅ Yes               | 26×8 systolic array target                     |
| Standard Convolution (3×3)    | ✅ Yes               | Mapped via spatial unrolling                   |
| ReLU / ReLU6                  | ✅ Yes               | Hardware activation unit                       |
| Leaky ReLU (α=0.125)          | ✅ Yes               | Hardware arithmetic right-shift                |
| HardSwish                     | ✅ Yes               | Dedicated 256-entry hardware LUT ROM           |
| 2×2 MaxPool / AvgPool         | ✅ Yes               | Dedicated hardware pooling unit                |
| Fully Connected / Softmax     | ❌ No                | Execute these on the PS7 ARM CPU               |

### 1.4 Recommended Model Architecture
We highly recommend architectures based on **YOLO-Nano** or **MobileNetV2** as they rely on Depthwise Separable Convolutions, which perfectly align with our hardware's dataflow.

---

## PART 2: Block Design Architecture Explained

The physical FPGA fabric is wired together using a Vivado Block Design. Here is a detailed breakdown of every component instantiated on the silicon, why we use it, and what it does.

### 1. ZYNQ7 Processing System (PS7)
- **What it does:** This is the dual-core ARM Cortex-A9 processor baked into the Zynq chip. It runs a Linux OS and your PYNQ Jupyter notebooks.
- **Why we use it:** It acts as the "brain" of the system. It initializes the NPU, sends the neural network weights over the AXI bus, and handles the high-level Python logic (like drawing the final bounding boxes or running a Kalman filter for predictive tracking).

### 2. DVI2RGB (HDMI Input Receiver)
- **What it does:** Takes the physical, high-speed TMDS differential signals coming from the camera's HDMI cable and decodes them into a parallel 24-bit RGB pixel stream.
- **Why we use it:** FPGAs only understand digital logic (1s and 0s). We need this Digilent IP block to translate the raw electrical HDMI signals into a clean pixel format our hardware can process.

### 3. V_VID_IN_AXI4S (Video to AXI-Stream)
- **What it does:** Wraps the raw RGB pixels into a standardized Xilinx protocol called AXI4-Stream.
- **Why we use it:** Our TinyNPU accelerator expects data in a standard streaming format with valid/ready handshakes. This block ensures the pixels are safely packaged so the NPU doesn't drop frames.

### 4. TinyNPU (NPU300PM Accelerator)
- **What it does:** Our custom-designed Ballistic Vision neural processing unit. It contains the 26x8 systolic array, line buffers, pooling units, and activation ROMs.
- **Why we use it:** This is the core of the project. It ingests the AXI-Stream pixels in real-time, runs the deep learning convolutions you trained at 125 MHz, and outputs the coordinates of the tracked drone.

### 5. V_AXI4S_VID_OUT (AXI-Stream to Video)
- **What it does:** Unwraps the processed AXI4-Stream pixels back into raw 24-bit RGB video signals.
- **Why we use it:** To display the tracking results on a monitor, we have to strip away the AXI networking headers and return to a raw pixel stream.

### 6. V_TC (Video Timing Controller)
- **What it does:** Acts as a metronome for the video output. It generates standard 720p timing signals (Horizontal Sync, Vertical Sync, and Blanking intervals).
- **Why we use it:** Monitors require strict timing pulses to know when to move the laser beam to the next line or next frame. The `V_TC` generates these pulses so the output monitor displays a stable image.

### 7. RGB2DVI (HDMI Output Transmitter)
- **What it does:** Encodes the raw 24-bit RGB pixels and the `V_TC` timing signals back into high-speed TMDS differential electrical signals.
- **Why we use it:** It is the exact opposite of DVI2RGB. It drives the physical HDMI OUT port on the PYNQ-Z2 board so you can plug it into a TV.

### 8. AXI Interconnects
- **What it does:** The "nervous system" of the FPGA. It is a network of multiplexers and routers.
- **Why we use it:** The PS7 ARM processor only has a few AXI ports, but it needs to talk to dozens of registers inside the TinyNPU and the V_TC. The Interconnect acts as a networking switch, allowing the single CPU to communicate with all hardware peripherals.

### 9. Processor System Reset
- **What it does:** Generates a synchronized, clean reset signal across the entire FPGA fabric.
- **Why we use it:** When the board powers on, different clocks start at different times. This block holds the entire system in reset until all clocks (125 MHz compute, 74.25 MHz pixel clock) are perfectly stable, preventing the hardware from crashing on boot.
