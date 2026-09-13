

# TinyNPU Project — Complete Study Guide for the Zeroth Review
### *Written from the perspective of a VLSI Professor specialising in Front-End & Back-End Design*
### Saveetha Engineering College | 19EC702 Project Work Phase I

---

> [!IMPORTANT]
> This document is written assuming **zero prior knowledge** of the project. Read it end-to-end once slowly, then re-read the Expected Questions section just before the review. You will be able to confidently answer anything the panel asks.

---

## PART 1 — Foundations: What You Absolutely Must Know

Before understanding the project, you need these building blocks. Don't skip this section.

---

### 1.1 What is VLSI?

**VLSI (Very Large Scale Integration)** is the process of designing electronic circuits that contain **millions or billions of transistors** on a single chip. Your smartphone processor, GPU, and even the chip inside a smart card — all are VLSI chips.

VLSI design has two major phases:

| Phase | What It Covers |
|---|---|
| **Front-End Design** | Writing the logic in code (Verilog/VHDL), simulating it, verifying it works correctly |
| **Back-End Design** | Taking that logic and physically placing it on silicon — floor planning, routing, timing closure, power analysis |

> **This project is a Front-End project.** We write the hardware logic in Verilog RTL, simulate it, and implement it on an FPGA board (PYNQ-Z2). We are not doing actual silicon fabrication, but the RTL is written so that it *could* be sent for fabrication (ASIC-ready).

---

### 1.2 What is an FPGA?

An **FPGA (Field Programmable Gate Array)** is a chip that can be **reprogrammed** to behave like any digital circuit you design.

Think of it like a blank whiteboard — you "draw" your circuit onto it by loading a configuration file called a **bitstream**. Unlike a fixed chip (ASIC), you can reprogram an FPGA as many times as you want.

```
Your Verilog Code
      |
      v  (Synthesis + Place & Route)
  Bitstream (.bit file)
      |
      v  (Loaded onto FPGA)
  FPGA now behaves as your designed circuit
```

**Our FPGA board: PYNQ-Z2**
- Contains a **Zynq-7020 SoC** (System-on-Chip)
- Has two parts:
  - **PS (Processing System)**: A real ARM Cortex-A9 CPU that runs Linux and Python
  - **PL (Programmable Logic)**: The FPGA fabric where our TinyNPU circuit runs
- The PS and PL talk to each other over **AXI buses** (more on this below)

---

### 1.3 What is RTL?

**RTL (Register Transfer Level)** is a way to describe digital hardware using code. It describes how data moves between registers (memory elements) every clock cycle.

We write RTL in **Verilog** (a hardware description language). This is NOT the same as software programming. Key difference:

| Software (Python/C) | Hardware (Verilog RTL) |
|---|---|
| Executes one line at a time (sequential) | All blocks run simultaneously (parallel) |
| Runs on a CPU | Describes the circuit itself |
| `int x = a + b;` runs in nanoseconds | A hardware adder computes in picoseconds |
| You describe WHAT to compute | You describe HOW the circuit is wired |

A simple Verilog example — a flip-flop (1-bit memory):
```verilog
always @(posedge clk) begin
    if (!rst_n)
        q <= 0;       // reset
    else
        q <= d;       // capture input on clock edge
end
```

---

### 1.4 What is a Clock and Reset?

- **Clock (`clk`)**: A signal that alternates between 0 and 1 at a fixed frequency (e.g., 200 MHz = 200 million cycles per second). Every circuit is synchronised to this — all registers update on the **rising edge** of the clock.
- **Reset (`rst_n`)**: Initialises all registers to a known state. In our design it is **active-low** — meaning the reset is active when the signal is 0 (`rst_n = 0`), and the circuit runs normally when `rst_n = 1`.

---

### 1.5 What is a MAC Operation?

**MAC = Multiply-Accumulate**. It is the single most important computation in deep learning:

$$\text{output} = \text{output} + (A \times B)$$

Every convolutional layer in a neural network is billions of MAC operations. Our chip does **64 MACs every single clock cycle** simultaneously.

---

### 1.6 What is INT8 Quantisation?

Neural networks are usually trained with 32-bit floating point numbers (FP32). These are large and power-hungry. **Quantisation** converts them to smaller integers:

```
FP32 weight: 0.3142857...  (32 bits)
INT8 weight: 40            (8 bits — 4x smaller!)
```

- **Weights**: stored as INT8 (8-bit integers, range -128 to 127)
- **Activations**: also INT8
- **Accumulator**: INT32 (32-bit) — because multiplying two 8-bit numbers can produce up to 16 bits, and adding many of them needs 32 bits
- **Requantisation**: After accumulation, we convert INT32 back to INT8 using a scale factor

Formula for requantisation:
$$\text{INT8 output} = \text{clamp}\!\left(\text{round}\!\left(\frac{M_0}{2^n} \times (\text{INT32 acc} + \text{bias})\right), -128, 127\right)$$

Where $M_0$ and $n$ are pre-computed constants from the training process.

---

## PART 2 — The TinyNPU Project Explained Simply

---

### 2.1 What Problem Are We Solving?

Imagine you want to detect a bullet (projectile) flying at **300 metres per second** using a high-speed camera. The camera captures a frame, and your system needs to decide **"is there a bullet in this frame?"** in less than **500 microseconds** (0.0005 seconds).

Standard approach:
```
Camera → USB/PCIe → CPU/GPU → Neural Network Inference → Result
```
Problem: Just the PCIe transfer alone adds **5–50 ms of latency** — 10–100× too slow.

Our solution:
```
Camera → PYNQ-Z2 PS (Python) → FPGA PL (TinyNPU) → Result
```
The entire inference happens **on the same board as the camera interface**, in **microseconds**.

---

### 2.2 What Exactly is TinyNPU?

**TinyNPU (Tiny Neural Processing Unit)** is a custom hardware accelerator (a specialised chip/circuit) that:

1. Receives image/sensor data as a stream
2. Runs the data through a **convolutional neural network (CNN)** in hardware
3. Produces an output (feature map / classification result) in microseconds

It is implemented on the **FPGA PL (Programmable Logic)** of the PYNQ-Z2 board. Python code running on the **PS (ARM processor)** feeds it data and reads results.

---

### 2.3 The Big Picture — How the System Works

```
┌─────────────────────────────────────────────────────────┐
│                    PYNQ-Z2 Board                         │
│                                                          │
│  ┌──────────────────────┐    ┌──────────────────────┐   │
│  │  PROCESSING SYSTEM   │    │  PROGRAMMABLE LOGIC   │   │
│  │   (ARM Cortex-A9)    │    │   (TinyNPU on FPGA)   │   │
│  │                      │    │                       │   │
│  │  Linux OS            │    │  8x8 Systolic Array   │   │
│  │  Python Script       │◄──►│  AXI-Stream Sink/Src  │   │
│  │  PYNQ Overlay API    │    │  Requant + ReLU + Pool│   │
│  │  USB Camera (OpenCV) │    │  Controller FSM       │   │
│  └──────────────────────┘    └──────────────────────┘   │
│         (PS)                 AXI4-S DMA  (PL)           │
└─────────────────────────────────────────────────────────┘
```

**Step-by-step execution:**

1. **Python captures a frame** from the USB camera using OpenCV
2. **Python quantises** the frame from FP32 to INT8
3. **Python calls PYNQ DMA** to stream the INT8 data directly into the FPGA fabric
4. **TinyNPU controller** receives a START signal from Python (via AXI-Lite register write)
5. **Systolic array** computes all MAC operations in parallel
6. **Post-processing chain** converts INT32 accumulations back to INT8 and applies ReLU
7. **Result streams back** to Python via AXI-Stream DMA
8. **Python reads the output** and makes a decision (detect/classify)

---

## PART 3 — Core Hardware Concepts (The Heart of the Project)

---

### 3.1 The Systolic Array — The Main Engine

A **systolic array** is a 2D grid of processing elements (PEs) where data flows rhythmically (like a heartbeat — "systolic") through the array. Our array is **8 rows × 8 columns = 64 PEs**.

**Each PE does one thing:** `psum_out = psum_in + (activation × weight)`

```
              Activations stream RIGHT →
              ↓ col0    col1    col2 ...
Weight  ──► PE(0,0)─►PE(0,1)─►PE(0,2)─►...
flows   ──► PE(1,0)─►PE(1,1)─►PE(1,2)─►...
DOWN    ──► PE(2,0)─►PE(2,1)─►PE(2,2)─►...
            ...
              ↓         ↓        ↓
           psum0    psum1    psum2    (partial sums drain down)
```

**Why is it fast?** Because all 64 PEs compute simultaneously every clock cycle. At 200 MHz: `64 MACs × 200,000,000 = 12.8 billion MAC operations per second = 12.8 GOPS`.

**Weight-Stationary Dataflow:** Once weights are loaded into the PEs, they **stay there** (stationary) while activations stream through. This saves energy because we don't have to re-read weights from memory for every computation.

**Input Skewing:** To make activations arrive at the right PE at the right time, we deliberately delay each row's input by 1 clock cycle relative to the row above it. This creates a diagonal wave-front of computation.

---

### 3.2 The Controller FSM — The Traffic Director

An **FSM (Finite State Machine)** is a circuit that moves between defined states based on inputs. Our `npu_controller.v` has 8 states:

| State | What Happens |
|---|---|
| `ST_IDLE` | Waiting for Python to write START=1 to the control register |
| `ST_LOAD_WGT` | Loading weights from weight buffer into PE array |
| `ST_SETUP_WGT` | Arranging weights ready for computation |
| `ST_LOAD_ACT` | Reading input activations from BRAM into the array |
| `ST_COMPUTE` | The systolic array is running — MACs happening every cycle |
| `ST_DRAIN` | Collecting the final partial sums from the bottom of the array |
| `ST_STORE_OUT` | Pushing requantised results into the output FIFO |
| `ST_DONE` | Writing DONE=1 to status register, triggering interrupt to Python |

---

### 3.3 Memory Subsystem — Double Buffering

We have two types of on-chip memory:

**Activation Buffer** (stores input image data):
- Built from BRAM (Block RAM) on the FPGA
- Uses **Ping-Pong (Double) Buffering**:
  - While **Bank A** is being written to by the camera stream (Python DMA)
  - **Bank B** is being read by the systolic array for computation
  - Then they swap — this hides the data loading latency completely

**Weight Buffer** (stores neural network weights):
- Also BRAM-based
- Pre-loaded by the Python script via DMA before computation starts
- Supports parallel reads (all 8 column weights read simultaneously)

---

### 3.4 The Post-Processing Chain

After the systolic array produces INT32 partial sums, they go through 3 stages:

```
INT32 psums
    ↓
[Requantisation Unit]  — Converts INT32 → INT8 using M0 and n_shift
    ↓
[Activation Unit]      — Applies ReLU (clips all negative values to 0)
    ↓
[Pooling Unit]         — 2×2 Max Pooling (reduces spatial size by half)
    ↓
INT8 output features → Output FIFO → AXI-Stream Source → Python
```

**Requantisation detail (3-stage pipeline):**
1. Add signed bias to the INT32 accumulator
2. Multiply by $M_0$ (a pre-computed scale factor)
3. Arithmetic Right Shift by $n$ bits (equivalent to dividing by $2^n$), then clamp to [-128, 127]

---

### 3.5 AXI Bus Interfaces — How Blocks Talk to Each Other

**AXI (Advanced eXtensible Interface)** is an ARM industry standard for on-chip communication. Think of it as the "highway" connecting all blocks.

| Interface | Used For | How It Works |
|---|---|---|
| **AXI4-Lite** | Configuration registers (CSRs) | Python writes to specific addresses to configure M0, n_shift, bias, input size, and START bit |
| **AXI4-Stream** | Streaming data (activations in, results out) | Data flows continuously — `tvalid`/`tready` handshake protocol |
| **AXI4-DMA** | Bulk weight transfer from DDR3 memory | Autonomous burst transfers without CPU intervention |

**CSR Memory Map (you will be asked this):**

| Register | Address | Purpose |
|---|---|---|
| CTRL | 0x00 | Bit0=Start, Bit1=Reset |
| STATUS | 0x04 | Bit0=Busy, Bit1=Interrupt |
| WGT_BASE | 0x08 | DRAM base address of weights |
| ACT_BASE | 0x0C | DRAM base address of activations |
| M0_CFG | 0x2C | Requantisation scale multiplier |
| SHIFT_CFG | 0x30 | Requantisation shift amount |
| BIAS_CFG | 0x34 | Requantisation bias value |

---

### 3.6 The Python Frontend — How We Feed Data

This is what runs on the **ARM PS side** of PYNQ-Z2:

```python
from pynq import Overlay
import numpy as np, cv2

# 1. Load the TinyNPU bitstream onto FPGA PL
ol = Overlay('tinynpu.bit')
dma = ol.axi_dma
cam = cv2.VideoCapture(0)           # USB camera

# 2. Configure TinyNPU via AXI-Lite (write CSRs)
ol.axi4_lite_slave.write(0x2C, M0_VALUE)     # scale factor
ol.axi4_lite_slave.write(0x30, SHIFT_VALUE)  # shift amount
ol.axi4_lite_slave.write(0x34, BIAS_VALUE)   # bias

# 3. Capture frame and quantise
_, frame = cam.read()
quant_frame = quantize_to_int8(frame, scale)

# 4. Allocate contiguous DMA buffer and copy
input_buf = allocate(shape=(H, W), dtype=np.int8)
input_buf[:] = quant_frame

# 5. Stream to FPGA PL and trigger
dma.sendchannel.transfer(input_buf)
ol.axi4_lite_slave.write(0x00, 0x1)          # START=1

# 6. Wait and read result
dma.sendchannel.wait()
output_buf = allocate(shape=(OUT_H, OUT_W), dtype=np.int8)
dma.recvchannel.transfer(output_buf)
result = np.array(output_buf)
```

---

## PART 4 — Design Decisions and Why We Made Them

This is what professors love to ask. Know the **"why"** behind each choice.

| Decision | What We Did | Why |
|---|---|---|
| **Dataflow** | Weight-Stationary | Weights are small in count but accessed many times — keeping them in PEs avoids repeated expensive BRAM reads |
| **Quantisation** | INT8 (not FP32) | INT8 uses 4× less memory, 4× less bandwidth, and integer math is much faster in hardware |
| **Clock domain** | Single clock for all blocks | Multiple clock domains cause metastability (bit-flip errors at boundaries) — one clock eliminates all CDC problems |
| **Reset style** | Synchronous active-low | Synchronous reset is more predictable and avoids glitches; active-low is an industry convention |
| **Memory style** | Double-buffered BRAM | Hides data transfer latency — compute and load happen simultaneously, maximising utilisation |
| **Bus protocol** | AXI4 standard | AXI4 is ARM's open standard — synthesisable, well-documented, and works seamlessly with PYNQ |
| **Target platform** | PYNQ-Z2 FPGA (not GPU) | FPGA gives deterministic, fixed latency; GPUs are fast but have variable OS scheduling overhead |

---

## PART 5 — FPGA Resources Used

On the Zynq-7020 (Artix-7 fabric):

| Resource | Used | Reason |
|---|---|---|
| **DSP48E1 slices** | 64 (one per PE) | Each DSP block does one INT8×INT8 multiply in hardware |
| **BRAMs (18Kb/36Kb)** | 4–6 blocks | Activation buffer + weight buffer ping-pong banks |
| **LUTs** | ~2,500 | Controller FSM, requantiser, muxes, address decoders |
| **Flip-Flops (FFs)** | ~3,000 | Pipeline registers, skew registers, output staging |

---

## PART 6 — EXPECTED REVIEW QUESTIONS & MODEL ANSWERS

Read this section multiple times. These are the most likely questions from the panel.

---

### Q1. "What is TinyNPU and what problem does it solve?"

**Answer:**
TinyNPU is a hardware neural network accelerator implemented on the PYNQ-Z2 FPGA board. It solves the latency problem in ballistic vision applications — detecting fast-moving objects like projectiles traveling over 300 m/s. Standard GPU or CPU-based inference has 5 to 50 milliseconds of latency due to PCIe bottlenecks and OS scheduling. TinyNPU eliminates this by placing the CNN inference engine right next to the sensor, achieving single-digit microsecond latency.

---

### Q2. "Explain what a systolic array is and why you chose it."

**Answer:**
A systolic array is a 2D grid of processing elements (PEs) where data flows rhythmically — each PE does a multiply-accumulate (MAC) and passes results to the next PE. We use an 8×8 array with 64 PEs, all computing simultaneously every clock cycle. We chose it because it offers predictable, deterministic throughput with high hardware efficiency — 64 MACs per cycle at 200 MHz gives 12.8 billion operations per second. Unlike GPU cores that share memory bandwidth, each PE in a systolic array has its own data path, eliminating memory bottlenecks.

---

### Q3. "What is Weight-Stationary dataflow and why not Output-Stationary?"

**Answer:**
In Weight-Stationary dataflow, filter weights are loaded once into the PEs and stay there while activations stream through the array. This minimises the number of times we read weights from memory — the most energy-expensive operation. In Output-Stationary, the partial sums stay in place and both weights and activations stream through — this is better when you want to minimise data movement for outputs, but requires more complex data routing. We chose Weight-Stationary because in CNN inference, the same weights are reused many times across the input spatial dimensions, making it the most energy-efficient choice.

---

### Q4. "Why INT8 quantisation? What are the tradeoffs?"

**Answer:**
INT8 quantisation reduces weight and activation precision from 32-bit floating point to 8-bit integers. Benefits: 4× less memory, 4× less bandwidth, integer arithmetic is significantly faster and simpler in hardware, and power consumption is much lower. The tradeoff is a small drop in model accuracy — typically 0.5 to 2% on standard benchmarks, which is acceptable for real-time detection tasks. We handle the precision loss using the requantisation unit which uses a scale factor M0 and shift n to maintain accuracy.

---

### Q5. "What is the purpose of double-buffering? Explain the ping-pong mechanism."

**Answer:**
Double-buffering (ping-pong) uses two memory banks instead of one. While Bank A is being read by the systolic array for the current computation, Bank B is simultaneously being written with the next frame's data from the DMA. When computation finishes, they swap roles. Without this, the systolic array would have to wait while the new data loads — wasting cycles. With double-buffering, loading and computing happen in parallel, hiding the memory latency completely and maximising throughput.

---

### Q6. "What is AXI4 and what are the three types you use?"

**Answer:**
AXI4 (Advanced eXtensible Interface 4) is ARM's industry-standard on-chip communication protocol. We use three variants:
- **AXI4-Lite**: For slow configuration register reads/writes (Python writes M0, n_shift, bias, START bit). Simple single-beat transactions.
- **AXI4-Stream**: For high-bandwidth streaming data — input activations flow in from Python, output results flow out to Python. Uses a tvalid/tready handshake.
- **AXI4 Master (DMA)**: For autonomous bulk weight transfers from DDR3 memory to the weight buffer without CPU intervention.

---

### Q7. "Explain the requantisation process step by step."

**Answer:**
After the systolic array accumulates INT8 multiplications, the result is a 32-bit integer (INT32). We need to convert it back to INT8 in three steps:
1. **Bias addition**: Add the pre-trained bias term to the INT32 accumulator
2. **Scale multiplication**: Multiply by M0 — a fixed-point representation of the scale factor needed to map the INT32 range back to the INT8 range
3. **Arithmetic right shift and clamp**: Shift right by n bits (equivalent to dividing by 2^n) to get the final value, then clamp it to [-128, 127] to fit in INT8

This implements the mathematical formula: `output = clamp(round((acc + bias) × M0 × 2^(-n)), -128, 127)`

---

### Q8. "Why did you choose PYNQ-Z2? What is the role of the ARM processor?"

**Answer:**
PYNQ-Z2 contains a Zynq-7020 SoC with both an ARM Cortex-A9 dual-core processor (the PS) and Artix-7 FPGA fabric (the PL) on the same chip. The ARM processor runs Linux and Python — it handles camera capture via OpenCV, INT8 quantisation of frames, AXI-Lite register configuration, and DMA transfers. The FPGA PL handles all the heavy computation (MAC operations) with deterministic timing. This PS-PL architecture is ideal because Python gives us programmability and ease of use, while the FPGA gives us the speed and determinism that CPUs cannot provide.

---

### Q9. "What is the critical path in your design? How do you fix it?"

**Answer:**
The critical path is the longest combinational logic path between any two registers — it determines the maximum operating frequency. In TinyNPU, the critical path is inside the systolic array's multiply-accumulate chain: the INT8 multiplier output feeds directly into the 32-bit adder (accumulator). This is a long path at high frequencies. The fix is to insert pipeline registers between the multiplication and accumulation stages, breaking the long path into shorter segments. This allows higher clock frequencies at the cost of 1 extra cycle of latency.

---

### Q10. "What is metastability and how does your design avoid it?"

**Answer:**
Metastability occurs when a flip-flop receives a data input that changes too close to the clock edge — the output enters an unstable intermediate state (neither 0 nor 1) for an unpredictable time. This typically happens when crossing between different clock domains (CDC — Clock Domain Crossing). Our design uses a **single synchronous clock domain** for all blocks, which completely eliminates CDC and metastability risks. There are no asynchronous signals crossing between clock domains.

---

### Q11. "How does Python feed data to the FPGA? Explain the PYNQ API."

**Answer:**
Python uses the PYNQ Overlay API:
1. `Overlay('tinynpu.bit')` loads the TinyNPU bitstream onto the FPGA PL
2. `allocate(shape, dtype)` allocates a physically contiguous memory buffer in DDR3 (required for DMA)
3. The quantised INT8 frame is copied into this buffer
4. `dma.sendchannel.transfer(buffer)` initiates a DMA burst transfer from DDR3 to the FPGA PL via AXI4-Stream and the HP0 (High Performance) port
5. Python writes `START=1` to the AXI-Lite control register
6. `dma.recvchannel.transfer(output_buffer)` reads the result back from the FPGA PL
7. The result is converted to a NumPy array for processing

---

### Q12. "Can this design be migrated to an ASIC? What changes would be needed?"

**Answer:**
Yes, the RTL is written to be ASIC-ready — we intentionally avoided any vendor-specific primitives. Changes needed for ASIC migration:
1. **Replace BRAMs** with compiled SRAM macros from a memory compiler (the BRAM is FPGA-specific)
2. **Replace DSP48E1 blocks** with synthesised integer multipliers from standard-cell libraries
3. **Add DFT (Design for Test)** — insert scan chains for manufacturing test
4. **Add clock gating cells** to reduce dynamic power when blocks are idle
5. **Run through a full PD flow**: floorplanning, placement, CTS (Clock Tree Synthesis), routing, DRC/LVS checks
A TSMC 28nm process node would achieve significantly higher frequency and much lower power than the FPGA implementation.

---

### Q13. "What is your theoretical peak performance? How did you calculate it?"

**Answer:**
Peak performance is calculated as:

$$\text{GOPS} = \text{Number of MACs} \times 2 \times \text{Clock Frequency}$$

- Number of PEs: 64 (8×8 array)
- Each PE does 1 MAC per cycle = 1 multiply + 1 add = **2 operations**
- Clock frequency: 200 MHz

$$\text{Peak} = 64 \times 2 \times 200 \times 10^6 = 25.6 \text{ GOPS}$$

In practice, throughput is lower due to bubble cycles during weight loading, output drain, and BRAM access latency. Double-buffering significantly reduces these overheads.

---

### Q14. "What is the difference between synthesis and simulation?"

**Answer:**
- **Simulation**: Running the Verilog code in software (like Vivado XSIM) to verify the **functional behaviour** of the design. We apply test inputs and check that outputs match expected values. This confirms logic correctness but tells us nothing about timing.
- **Synthesis**: Converting the Verilog RTL into an actual netlist of gates (AND, OR, flip-flops, etc.) and mapping them to the target technology (FPGA LUTs or ASIC standard cells). After synthesis, we know the resource utilisation and can begin timing analysis (STA — Static Timing Analysis).

Both are essential. We always simulate first to catch logic bugs, then synthesise to check implementation feasibility.

---

### Q15. "What is your verification strategy?"

**Answer:**
We use a three-layer verification approach:
1. **Golden Reference Model (Python)**: We first run the exact same computation in Python (software simulation) and record the expected outputs for a set of test inputs
2. **RTL Simulation (Vivado XSIM)**: We run the testbench `tinynpu_top_tb.sv` which applies the same inputs to the RTL and compares outputs byte-by-byte against the Python golden reference. Any mismatch is flagged
3. **AXI Protocol Assertions**: We add SystemVerilog assertions to verify that AXI handshaking rules (tvalid/tready) are never violated

---

## PART 7 — Quick Glossary (Flash Card Reference)

| Term | Meaning |
|---|---|
| **MAC** | Multiply-Accumulate: `acc = acc + (A × B)` — core deep learning operation |
| **Systolic Array** | 2D grid of PEs where data flows rhythmically; all 64 PEs compute in parallel |
| **PE** | Processing Element — one MAC unit in the systolic array |
| **Psum** | Partial Sum — intermediate accumulation result flowing through the array |
| **INT8** | 8-bit signed integer (-128 to 127) — quantised data format |
| **Requantisation** | Converting INT32 accumulation back to INT8 using M0 × 2^(-n) |
| **FSM** | Finite State Machine — a circuit that controls sequencing through defined states |
| **BRAM** | Block RAM — dedicated on-chip memory blocks on the FPGA |
| **Ping-Pong** | Two memory banks alternating between write (load) and read (compute) roles |
| **AXI4-Lite** | Low-speed ARM bus for register configuration |
| **AXI4-Stream** | High-speed ARM bus for continuous data streaming (no addressing) |
| **DMA** | Direct Memory Access — transfers data without CPU intervention |
| **CSR** | Control and Status Register — memory-mapped registers for hardware config |
| **Skewing** | Delaying each row's activation input by 1 cycle to align the wavefront |
| **Deskewing** | Compensating for skew at the output to align partial sum columns |
| **CDC** | Clock Domain Crossing — where signals cross between two different clocks |
| **Metastability** | An unstable flip-flop state caused by a setup/hold violation at a CDC |
| **STA** | Static Timing Analysis — verifying all paths meet setup and hold constraints |
| **Critical Path** | Longest combinational delay path — determines max clock frequency |
| **Overlay** | In PYNQ, a bitstream + Python API for a specific FPGA design |
| **GOPS** | Giga Operations Per Second — measure of compute throughput |
| **Weight-Stationary** | Dataflow where weights stay in PEs; activations stream through |
| **Im2Col** | Algorithm that reformulates convolution as matrix multiplication |
| **ReLU** | Rectified Linear Unit — activation function: `max(0, x)` |
| **Quantisation** | Reducing numerical precision (FP32 → INT8) to save memory and compute |
| **ASIC** | Application-Specific Integrated Circuit — custom silicon chip |
| **RTL** | Register Transfer Level — hardware description at the logic/register level |
| **Netlist** | Post-synthesis description of a design as interconnected logic gates |
| **Bitstream** | Configuration file that programs the FPGA to implement your circuit |
| **Zynq** | Xilinx SoC with ARM PS + Artix-7 FPGA PL on one chip |

---

## PART 8 — One-Page Summary (Read This 5 Minutes Before the Review)

```
PROJECT:   TinyNPU — AI accelerator on PYNQ-Z2 for ballistic vision
PROBLEM:   CPU/GPU pipelines = 5-50ms latency. Need < 500 microseconds.
SOLUTION:  FPGA-based systolic array NPU on PYNQ-Z2. Python feeds data
           via DMA. Hardware computes in microseconds.

HARDWARE:
  - 8x8 systolic array = 64 PEs = 64 MACs per cycle
  - INT8 weights + activations, INT32 accumulators
  - Requantisation: INT32 -> INT8 using M0 x 2^(-n)
  - Double-buffered BRAM (ping-pong)
  - AXI4-Lite (config) + AXI4-Stream (data) + AXI4-DMA (weights)
  - Single clock domain (200 MHz target)
  - Synchronous active-low reset

PYTHON FRONTEND:
  ol = Overlay('tinynpu.bit')         <- load onto FPGA
  ibuf = allocate((H,W), 'i1')        <- DMA buffer
  dma.sendchannel.transfer(ibuf)      <- stream to FPGA
  dma.recvchannel.transfer(obuf)      <- read result

PERFORMANCE:
  Peak: 64 x 2 x 200MHz = 25.6 GOPS
  Target latency: < 10 microseconds

BOARD: PYNQ-Z2
  PS: ARM Cortex-A9 + Linux + Python (runs the frontend)
  PL: Artix-7 FPGA fabric (runs TinyNPU circuit)
  Interface: AXI4-Stream DMA over HP0 port

KEY REASONS FOR CHOICES:
  Weight-Stationary  -> saves weight read energy
  INT8 quantisation  -> 4x smaller, 4x faster, hardware-friendly
  Single clock       -> no metastability, simple timing
  Double buffer      -> hide load latency, max throughput
  PYNQ-Z2           -> PS+PL on same chip, Python programmability
  AXI4              -> industry standard, synthesisable
```

---

> [!TIP]
> **Before the review:** Read Part 5 (Expected Q&A) out loud to yourself. If you can explain each answer in 3–4 sentences confidently, you are fully prepared.

> [!NOTE]
> The panel is primarily checking whether you understand **why decisions were made**, not just **what was built**. Always connect your answer back to the problem: latency, determinism, and efficiency.

---

*Document prepared for the Zeroth Project Review — 05 August 2026*
*Saveetha Engineering College | Department of ECE | 19EC702 Project Work Phase I*
