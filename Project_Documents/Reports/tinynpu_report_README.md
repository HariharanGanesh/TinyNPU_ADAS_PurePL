# TinyNPU: A Sensor-Aware Reconfigurable AI Accelerator for Ultra-High-Speed Ballistic Vision

## Overview
TinyNPU is an FPGA-first, ASIC-ready AI hardware accelerator designed to perform low-latency, high-throughput convolutional and matrix-multiplication operations on ultra-high-speed streaming data. The architecture is tailored for ballistic vision applications—such as projectile detection and real-time tracking—where decision latencies must remain sub-microsecond. The design utilizes an 8×8 weight-stationary systolic array, integrated with double-buffered local memories, fused requantization, activation, and pooling units, and standard AXI4-compliant communication interfaces.

---

## Problem Statement
Standard high-speed camera pipelines transfer raw pixel arrays to general-purpose GPUs or CPUs for inference. This paradigm incurs severe latency overheads due to PCI Express bottlenecks, OS scheduling, and memory page transfers. For ballistic vision (e.g., intercepting micro-projectiles traveling at >300 m/s), the total budget for sensor read, frame ingestion, and model inference is less than 500 microseconds. TinyNPU addresses this by acting as a near-sensor coprocessor that consumes pixel streams on-the-fly, executes INT8-quantized CNN layers in hardware, and writes output activations with minimal cycle overhead.

---

## Objectives
1. **Ultra-Low Latency**: Enable single-digit microsecond latency for 2D convolutional and fully connected layers.
2. **Deterministic Execution**: Avoid dynamic branch predictors or shared caches, ensuring strict cycle-by-cycle execution predictability.
3. **Resource Efficiency**: Maximize Xilinx Spartan-7 XC7S50 resource utilization (limiting BRAM and DSP tile usage) while maintaining high computing throughput.
4. **ASIC Migration Readiness**: Maintain strict vendor-neutral, synthesizable Verilog RTL without using vendor-specific hard-macro instantiations.

---

## Key Features
- **Weight-Stationary Dataflow**: Minimizes weight memory read energy by holding filter coefficients stationary inside the Processing Elements (PEs) while streaming activations across the array.
- **Saturating INT8 Quantization**: Fuses scale-factor multiplication, rounding, and arithmetic shift right (ASR) to convert INT32 accumulations back to INT8 activations.
- **Depthwise-Separable Convolution Engine**: Integrates a dedicated 3x3 depthwise line-buffer engine to accelerate modern lightweight CNN architectures (like MobileNet).
- **Double-Buffered Memory Subsystem**: Hides host weight-loading and streaming activation ingestion latency by double-buffering input memories.
- **Standard Bus Interfaces**: Control plane handled by AXI4-Lite; high-bandwidth data plane handled by AXI4-Stream (inbound/outbound) and AXI4-DMA (weights).

---

## Complete System Architecture

TinyNPU integrates the control, memory, compute, and post-processing subsystems into a single clock domain. The block diagram below illustrates the subcomponents:

```
                                  +------------------------------------+
                                  |            AXI4-Lite Slave         |
                                  |  - Register file config & control  |
                                  +-----------------+------------------+
                                                    | (CSRs)
                                                    v
+------------------------+        +-----------------+------------------+
|    AXI4-Stream Sink    |        |           Controller FSM           |
| - Ingests activations  |        | - Coordinates load/compute/drain   |
+-----------+------------+        +--------+--------+--------+---------+
            |                              |        |        |
            v (Ping/Pong toggle)           |        |        v (Weight write)
+-----------+------------+                 |        |  +-----+------------+
|   Activation Buffer    |                 |        |  |  Weight Buffer   |
| - 2x 256x64 BRAM bank  |                 |        |  | - 2x 1024x64 BRAM  |
+-----------+------------+                 |        |  +-----+------------+
            |                              |        |        |
            | (Skewed Act Stream)          |        |        | (Stationary Weights)
            v                              v        |        v
+-----------+------------------------------+----+   |  +-----+------------+
|             Systolic Array Compute Grid       |   |  | Depthwise Engine |
|             - 8x8 Processing Elements         |   |  | - 3x3 Line Buffer|
+--------------------------+--------------------+   |  +-----+------------+
                           |                        |        |
                           | (INT32 Psums)          |        | (INT32 DW Psums)
                           v                        v        v
                        +--+------------------------+--------+---+
                        |             Multiplexer Mux            |
                        +-------------------+--------------------+
                                            | (INT32 Selected Psums)
                                            v
                        +-------------------+--------------------+
                        |           Requantization Unit          |
                        |  - Bias addition, M0, Shift, Round     |
                        +-------------------+--------------------+
                                            | (INT8 Requantized)
                                            v
                        +-------------------+--------------------+
                        |            Activation Unit             |
                        |  - ReLU / Clamp Logic                  |
                        +-------------------+--------------------+
                                            | (INT8 Activated)
                                            v
                        +-------------------+--------------------+
                        |             Pooling Unit               |
                        |  - 2x2 Max / Avg / Bypass              |
                        +-------------------+--------------------+
                                            | (INT8 Pooled)
                                            v
                        +-------------------+--------------------+
                        |            Output Buffer               |
                        |  - FIFO synchronization buffer         |
                        +-------------------+--------------------+
                                            |
                                            v
                        +-------------------+--------------------+
                        |           AXI4-Stream Source           |
                        |  - Streams out final results           |
                        +----------------------------------------+
```

---

## High-Level Data Flow
1. **Weight Loading**: The host system writes weights to the `weight_buffer` via DMA.
2. **Activation Ingestion**: The camera sensor streams pixel activations into the `activation_buffer` via `axis_sink`.
3. **Execution Trigger**: The host configures model parameters via AXI-Lite and starts execution by writing to the `START` register.
4. **Systolic Loading**: The controller fetches weights from the `weight_buffer` and programs them into the array's PEs.
5. **Computation**: Activations are read from `activation_buffer`, skewed, and fed to the systolic array. Partial sums propagate downward and accumulate results.
6. **Drain & Post-Process**: Computed partial sums drain from the bottom of the array, pass through requantization (bias + scale + shift + round), activation (ReLU), and pooling, and are pushed into the output FIFO.
7. **Output Streaming**: The `axis_source` drains the output FIFO and transfers processed data to the downstream host or network processor.

---

## Hardware Blocks

### 1. `tinynpu_top.v`
- **Purpose**: Integrates the entire accelerator. Instantiates memory buffers, systolic array, post-processing blocks, controllers, and AXI buses.
- **Inputs**: `clk`, `rst_n`, AXI4-Lite config signals, AXI4-Stream input/output signals, AXI4 weight-loading interface.
- **Outputs**: Outbound AXI4-Stream data and status interrupts.
- **Internal Working**: Combines CSR values, controls buffer write-enables, manages ping-pong toggling, and routes signals between subsystems.
- **Dependencies**: Instantiates all sub-modules below.

### 2. `processing_element.v`
- **Purpose**: Performs a single-cycle multiply-accumulate (MAC) operation.
- **Inputs**: `clk`, `rst_n`, `act_in` (8-bit), `weight_in` (8-bit), `psum_in` (32-bit), `weight_load` (1-bit).
- **Outputs**: `act_out` (8-bit), `weight_out` (8-bit), `psum_out` (32-bit).
- **Internal Working**: Contains a local register to store the stationary weight. When `weight_load` is high, it updates the weight register. On every clock cycle, it computes `psum_out <= psum_in + (act_in * weight_reg)` and forwards `act_in` to the right (`act_out`) and the weights downward (`weight_out`) to enable 2D grid propagation.
- **Dependencies**: None.

### 3. `systolic_array.v`
- **Purpose**: Aggregates the 8×8 PE grid and handles input skewing and output deskewing.
- **Inputs**: `clk`, `rst_n`, `weight_data_flat` (64-bit), `weight_load` (1-bit), `act_in_flat` (64-bit), `act_valid_in_flat` (8-bit), `array_en` (1-bit), `psum_clear` (1-bit).
- **Outputs**: `psum_out_flat` (256-bit), `psum_valid_out_flat` (8-bit).
- **Internal Working**: Instantiates 64 PEs in an 8×8 matrix. Skews input activations by delaying each row's input by 1 cycle relative to the row above it, matching the diagonal wavefront of data. Deskews output partial sums using pipeline registers to output aligned column results.
- **Dependencies**: `processing_element.v`.

### 4. `npu_controller.v`
- **Purpose**: Core control logic. Operates the primary execution FSM.
- **Inputs**: `clk`, `rst_n`, `start`, layer parameter configurations, buffer status flags, execution step signals.
- **Outputs**: `busy`, `done`, write-enables, address pointers, systolic control lines.
- **Internal Working**: Sequences states to load weights into the array, stream activations from buffer to grid, drain results, and trigger interrupts on completion.
- **Dependencies**: None.

### 5. `dma_controller.v`
- **Purpose**: Manages autonomous AXI read/write bursts to fetch weights from system memory without CPU intervention.
- **Inputs**: `clk`, `rst_n`, register controls, AXI read data.
- **Outputs**: Memory addresses, burst control signals.
- **Internal Working**: Translates weight base address configurations into AXI read commands, unpacking streams and writing them directly into the weight buffers.
- **Dependencies**: None.

### 6. `activation_buffer.v`
- **Purpose**: Stores input activations.
- **Inputs**: `clk`, `rst_n`, write/read ports, ping-pong toggle signals.
- **Outputs**: `rd_data`.
- **Internal Working**: Dual-ported BRAM banks configured in ping-pong style. While Bank A is receiving data from the camera interface, Bank B is serving data to the systolic array.
- **Dependencies**: None.

### 7. `weight_buffer.v`
- **Purpose**: Holds filter weights for current/upcoming layers.
- **Inputs**: `clk`, `rst_n`, write/read ports.
- **Outputs**: `rd_data`.
- **Internal Working**: Multi-bank SRAM configured to support parallel reads of 8 columns of weights to load the systolic array columns concurrently.
- **Dependencies**: None.

### 8. `output_buffer.v`
- **Purpose**: Buffers outbound data to smooth differences in throughput.
- **Inputs**: `clk`, `rst_n`, `wr_en`, `rd_en`, `wr_data`.
- **Outputs**: `rd_data`, `full`, `empty`.
- **Internal Working**: A standard FIFO buffer that decouples NPU execution speed from the external AXI4-Stream master bandwidth.
- **Dependencies**: None.

### 9. `requantization_unit.v`
- **Purpose**: Downscales INT32 accumulated outputs to INT8 activations using fixed-point scale factors.
- **Inputs**: `clk`, `rst_n`, `acc_in_flat`, `M0_flat`, `n_shift_flat`, `bias_flat`, `acc_valid`.
- **Outputs**: `quant_out_flat`, `quant_valid`.
- **Internal Working**: Implements a 3-stage pipeline:
  1. Add signed bias to INT32 accumulator, then multiply by `M0` scale factor.
  2. Perform rounded right shift by `n_shift` positions.
  3. Clamp the resulting value to `[-128, 127]` limits.
- **Dependencies**: None.

### 10. `activation_unit.v`
- **Purpose**: Applies activation functions.
- **Inputs**: `clk`, `rst_n`, `data_in_flat`, `act_sel` (2-bit), `valid_in`.
- **Outputs**: `data_out_flat`, `valid_out`.
- **Internal Working**: Configurable activation block:
  - `00`: ReLU (clips values below 0)
  - `01`: LeakyReLU (not implemented / bypass)
  - `10`: Bypass (identity)
- **Dependencies**: None.

### 11. `pooling_unit.v`
- **Purpose**: Reduces spatial dimensions to compress output maps.
- **Inputs**: `clk`, `rst_n`, `data_in_flat`, `pool_mode`, `valid_in`.
- **Outputs**: `data_out_flat`, `valid_out`.
- **Internal Working**: Computes max or average over sliding windows (configurable bypass).
- **Dependencies**: None.

### 12. `axis_sink.v`
- **Purpose**: Ingests streaming input data from external sensor/bus.
- **Inputs**: AXI4-Stream signals (`tvalid`, `tdata`, `tlast`, `tready`).
- **Outputs**: Buffer write control signals.
- **Internal Working**: Converts external stream handshake transactions into sequential address write sequences for the activation buffer.
- **Dependencies**: None.

### 13. `axis_source.v`
- **Purpose**: Emits processed output data as AXI4-Stream transfers.
- **Inputs**: `clk`, `rst_n`, output buffer FIFO status.
- **Outputs**: Inbound stream handshake feedback.
- **Internal Working**: Observes downstream `tready` and FIFO empty lines to orchestrate outbound transfers with proper packaging.
- **Dependencies**: None.

### 14. `axi4_lite_slave.v`
- **Purpose**: Implements the Control and Status Register (CSR) file.
- **Inputs**: Host read/write transactions.
- **Outputs**: Register configs mapped to accelerator hardware.
- **Internal Working**: Decodes transaction addresses to configure registers like `M0`, `n_shift`, `bias`, memory bases, and trigger control bits.
- **Dependencies**: None.

### 15. `dw_line_buffer.v`
- **Purpose**: Accelerates Depthwise convolutions.
- **Inputs**: `clk`, `rst_n`, line buffer addresses.
- **Outputs**: Sliding window data.
- **Internal Working**: Contains row shift-registers storing lines of pixels, allowing 3×3 receptive fields to feed depthwise compute logic in parallel.
- **Dependencies**: None.

---

## Folder Structure
```
d:\Final year project/
├── constraints/                   # Timing and pin constraint files (.xdc)
├── docs/                          # Architecture specification sheets
├── model/                         # Python golden simulator model
├── rtl/                           # Synthesizable RTL source files
│   ├── activation/                # ReLU activation logic
│   ├── axi/                       # AXI Lite/Stream converters
│   ├── buffers/                   # SRAM ping-pong memory banks
│   ├── control/                   # Controller state machines
│   ├── dma/                       # Weight DMA engines
│   ├── dw_engine/                 # Depthwise line buffer
│   ├── pe/                        # Multiply-accumulate PE cells
│   ├── pooling/                   # Max pooling operations
│   ├── quantization/              # Fixed-point downscalers
│   ├── systolic_array/            # Skewed array architecture
│   └── top/                       # Top-level module
└── verif/                         # Verification testbenches
    └── tb/                        # Testbench vectors and SV testbench
```

---

## Module Dependency Diagram
```
              [ tinynpu_top.v ]
             /        |        \
            v         v         v
   [axi_lite_slave] [axis_sink] [axis_source]
            |         |         |
            v         v         v
   [npu_controller] [activation_buffer] [output_buffer]
            |         |         |
            v         v         v
   [dma_controller] [weight_buffer]     |
            |         |                 |
            v         v                 |
   [systolic_array] [dw_line_buffer]    |
            |         |                 |
            v         v                 |
   [processing_element]                 |
            \         /                 |
             v       v                  |
       [ requantization_unit ] <--------+
                 |
                 v
       [  activation_unit  ]
                 |
                 v
       [   pooling_unit    ]
```

---

## Block Diagram (ASCII)
```
          ACTIVATIONS (8-bit)                   WEIGHTS (8-bit)
         ┌───────────────┐                     ┌───────────────┐
         │     col 0     │                     │     row 0     │
         └───────┬───────┘                     └───────┬───────┘
                 │ (skewed by delay)                   │
                 v                                     v
           ┌───────────┐                         ┌───────────┐
           │ PE (0,0)  │◀────────────────────────│ PE (0,1)  │
           └─────┬─────┘                         └─────┬─────┘
                 │                                     │
                 v (psum downstream)                   v
           ┌───────────┐                         ┌───────────┐
           │ PE (1,0)  │                         │ PE (1,1)  │
           └─────┬─────┘                         └─────┬─────┘
                 │                                     │
                 v                                     v
                 └────────────────► ACCUMULATOR ───────┘
```

---

## Data Flow Diagram
```
[Sensor Stream] -> [AXI-S Sink] -> [Act Buffer] -> [Skew Registers] 
                                                         |
                                                         v
[DRAM Weights]  -> [DMA Master] -> [Wgt Buffer] -> [Systolic Grid] -> [Psums]
                                                         |
                                                         v
[Output Stream] <- [AXI-S Src]  <- [Out FIFO]  <- [Post-Process Block]
```

---

## State Machines

### Controller FSM (`npu_controller.v`)
- **`ST_IDLE`**: Awaiting host trigger.
- **`ST_LOAD_WGT`**: Programming PE array with filter weights.
- **`ST_LOAD_ACT`**: Reading input activations.
- **`ST_SETUP_WGT`**: Arranging weights for computation.
- **`ST_COMPUTE`**: Feeding activation wavefronts and executing MAC operations.
- **`ST_DRAIN`**: Collecting resulting partial sums.
- **`ST_STORE_OUT`**: Pushing requantized outputs to Output Buffer.
- **`ST_DONE`**: Writing completion bits to CSR.

---

## Memory Map

CSR registers mapped via AXI-Lite space:

| Register | Offset | Access | Description |
|---|---|---|---|
| `ADDR_CTRL` | `0x00` | R/W | Bit 0: Start, Bit 1: Reset |
| `ADDR_STATUS` | `0x04` | R | Bit 0: Busy, Bit 1: Interrupt pending |
| `ADDR_WGT_BASE` | `0x08` | R/W | DRAM address base for weight loading |
| `ADDR_ACT_BASE` | `0x0C` | R/W | DRAM address base for activations |
| `ADDR_OUT_BASE` | `0x10` | R/W | DRAM address base for output dumping |
| `ADDR_LAYER_CFG0`| `0x14` | R/W | Layer parameters (K, stride, pad, activation select) |
| `ADDR_LAYER_CFG1`| `0x18` | R/W | Layer dimensions (input channels, output channels) |
| `ADDR_LAYER_CFG2`| `0x1C` | R/W | Spatial dimensions (input height, input width) |
| `ADDR_M0_CFG` | `0x2C` | R/W | Requantization scale multiplier ($M_0$) |
| `ADDR_SHIFT_CFG` | `0x30` | R/W | Requantization shift amount ($n$) |
| `ADDR_BIAS_CFG` | `0x34` | R/W | Requantization bias value |

---

## Communication Interfaces
- **AXI4-Lite**: Register reads and writes. Supports single-beat non-pipelined transactions.
- **AXI4-Stream (Sink)**: Dynamic data intake. Connects directly to pixel processors.
- **AXI4-Stream (Source)**: Pushes processed features downstream.
- **AXI4 Master (DMA)**: Interface for weight prefetching.

---

## Clock Domains
TinyNPU operates inside a **Single Synchronous Clock Domain** (`clk`). 
- Advantages: Eliminates metastability hazards and the need for clock-domain crossing (CDC) synchronizers, simplifying timing closure.
- Disadvantage: The slowest block (typically the systolic array DSP pipeline) limits the entire system's operating frequency.

---

## Reset Strategy
Uses a **Synchronous Active-Low Reset** (`rst_n`).
- Ensures all registers reset in a clean, glitch-free state.
- Prevents routing-congestion issues associated with asynchronous reset distribution networks.

---

## Pipeline Structure
TinyNPU features a 5-stage processing pipeline:

```
[Fetch Activation] ──> [Systolic MAC (Grid)] ──> [Requant Stage] ──> [ReLU Clamp] ──> [Output FIFO]
   (Read BRAM)            (1 cycle/PE)            (3 cycles)         (1 cycle)        (Write Out)
```

---

## Algorithms Used
- **GEMM (General Matrix Multiply)**: Reformulates 2D convolution sliding windows as matrix multiplication (Im2Col).
- **Fixed-Point Requantization**: Implements the integer multiplication and arithmetic shift right (ASR) mapping algorithm to run integer-only inference:
  $$\text{Scale} \approx M_0 \times 2^{-n}$$

---

## Quantization Concepts
To reduce memory footprint and power consumption, the design uses **INT8 Quantization**:
- Weights: Signed 8-bit integers (`[-128, 127]`).
- Activations: Signed or unsigned 8-bit integers.
- Accumulators: Signed 32-bit integers to prevent arithmetic overflow during dot products.
- Downscaling: Converts INT32 back to INT8 using scale factor $M_0$ and shift $n$.

---

## Verification Strategy
- **Golden Reference Models**: Python-based models (`model/`) generate expected outputs for test cases.
- **Direct RTL Verification**: Vivado XSIM simulation (`tinynpu_top_tb.sv`) verifies block-level and top-level functionality.
- **AXI Compliance Checks**: Assertions verify valid AXI-Lite and AXI-Stream handshakes.

---

## Testbench Explanation
The primary testbench is [`tinynpu_top_tb.sv`](file:///d:/Final%20year%20project/verif/tb/tinynpu_top_tb.sv). It:
1. Resets the design.
2. Writes configuration parameters (shape, M0, shift, bias) via AXI-Lite.
3. Simulates weight loading by writing to the weight buffer.
4. Streams input activations into the AXI-Stream sink.
5. Starts the FSM.
6. Monitores execution status registers.
7. Reads outputs from the AXI-Stream master and compares them to `tc1_expected_out.txt`.

---

## Expected Waveforms

```
clk            __||__||__||__||__||__||__||__||__||__||__||__||__||__
tvalid_in      ______/¯¯¯¯¯¯¯¯¯¯¯¯¯\_________________________________
tready_out     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\________________________________
fsm_state      IDLE  | LOAD_ACT | COMPUTE  | DRAIN  | STORE_OUT | DONE
quant_valid    ____________________________/¯\___________________
tvalid_out     _______________________________/¯¯¯¯\_____________
```

---

## FPGA Resources Used (Target: Xilinx Spartan-7 XC7S50)
- **LUTs**: ~2,500 (control, register files, muxes, requantizer).
- **FFs**: ~3,000 (pipeline registers, shift registers).
- **DSP Blocks (DSP48E1)**: 64 (one per PE to execute 8×8 signed multiplication).
- **BRAMs (18Kb/36Kb)**: 4-6 blocks (ping-pong memory banks).

---

## ASIC Considerations
If migrating to an ASIC process node (e.g., TSMC 28nm):
1. **Memory Compiler RAMs**: Replace BRAM arrays with compiled Single-Port or Dual-Port SRAM macros.
2. **DSP Replacement**: Synthesize DSP multipliers into custom, standard-cell integer multipliers.
3. **Scan Chain**: Insert Design-for-Test (DFT) scan chains for manufacturing test coverage.
4. **Clock Gating**: Implement clock-gating cells to save dynamic power when blocks are idle.

---

## Performance Analysis
- **Theoretical Peak**: 64 MACs/cycle. At 200 MHz, this translates to $64 \times 2 \times 200 \times 10^6 = 25.6 \text{ GOPS}$.
- **Throughput Efficiency**: Reduced by bubble overheads during weight reload and output drain cycles. Double-buffering helps hide these overheads.

---

## Timing Considerations
- **Critical Path**: Located in the systolic array's multiplication-to-accumulation path. 
- **Fixes**: Pipeline registers are inserted between PEs to break long combinational paths, ensuring timing closure at higher frequencies.

---

## Area Considerations
- In ASIC, the 8×8 grid uses approximately $64 \times 1,500 \approx 96,000 \text{ gate equivalents}$ (GE).
- Memory buffers dominate the chip area. Memory compiler parameters should be selected to balance area and power.

---

## Power Considerations
- **Static Power**: Dominated by leakage currents in SRAM cells.
- **Dynamic Power**: Dominated by clock distribution networks and active DSP blocks. Power-optimizations like clock gating should be applied to idle modules.

---

## Scalability
The architecture is parameterized:
- Grid size can be scaled to 16×16 or 32×32 by modifying `ARRAY_ROWS` and `ARRAY_COLS`.
- Quantization bit-widths can be customized to support INT4 or INT16.

---

## Future Improvements
- **Unstructured Sparsity**: Add zero-detection logic to skip MAC cycles when activations are zero.
- **Transformer Support**: Extend post-processing to support Softmax and Layer Normalization.

---

## Real Industrial Applications
- Automotive safety (detecting collision hazards in <1 ms).
- Industrial sorting (high-speed sorting on conveyor belts).
- Aerospace tracking (high-speed projectile tracking).

---

## Common Interview Questions
1. **Explain the difference between Weight-Stationary and Output-Stationary dataflows.**
2. **How does a systolic array handle input skewing, and why is it necessary?**
3. **What is metastability, and how do you prevent it in multi-clock designs?**
4. **Explain the mathematical process of requantizing an INT32 accumulator to an INT8 activation.**
5. **How does double-buffering hide memory transfer latency?**

---

## Important Technical Terms
- **Systolic Array**: A network of processors that rhythmically compute and pass data through the system.
- **MAC (Multiply-Accumulate)**: The core arithmetic operation in digital signal processing: $a \leftarrow a + (b \times c)$.
- **Double-Buffering**: A memory configuration using two buffers in parallel to hide data transfer latency.
- **Im2Col**: An algorithm that reformulates sliding-window convolutions as matrix-matrix multiplications.
- **Static Timing Analysis (STA)**: A method of validating the timing performance of a design by checking all paths for setup and hold violations.

---

## Summary
TinyNPU implements a high-performance, deterministic execution pipeline for ballistic vision tasks. The design provides low latency, efficient resource usage, and is ready for ASIC migration.

***

# Mentoring Program Study Guide & Course plan

Welcome to your internship! This guide outlines the modules we will study. For each module, we will cover architecture, RTL details, synthesis, timing, verification, and wrap up with a coding exercise.

```
+-------------------------------------------------------------+
|                     TinyNPU Course Plan                     |
+-------------------------------------------------------------+
| Module 1: The Processing Element (PE) - Core compute engine |
| Module 2: The Systolic Array Grid - Skewing & Wavefront     |
| Module 3: Requantization Unit - Fixed-Point scaling & shift |
| Module 4: NPU Controller FSM - Sequencing execution        |
| Module 5: Memory Subsystem - Dual-port ping-pong buffers    |
| Module 6: AXI Sink/Source & Streaming Protocol              |
+-------------------------------------------------------------+
```

Ready to begin? Let's start with Module 1.
