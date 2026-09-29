# TinyNPU Architectural Evolution & Version History

This document catalogs the evolutionary lineage of the TinyNPU accelerator on the Xilinx Zynq-7020. It details the compute topology of each version, the advantages it brought, the hardware limitations (disadvantages) it uncovered, and the specific engineering bottlenecks that forced an upgrade to the next tier.

---

## 1. TinyNPU (The Baseline Prototype)
**Architecture**: 8x8 Systolic Array (64 INT8 MACs)
**Target Clock**: 100 MHz
**Peak Compute**: ~12.8 GOPS

**Advantages**:
- **Simplicity**: Extremely easy to route. Only consumed a small fraction of the Zynq-7020's 220 DSP48E1 slices.
- **Timing Safe**: The shallow 2-stage Processing Element (PE) pipeline easily met timing closure natively without advanced placement directives.

**Disadvantages**:
- **Severe Bottleneck**: 64 MACs provided too little parallel compute density to saturate the AXI Memory interconnect bandwidth. 
- **Low FPS**: CNN inference latency was too high for real-time video processing applications.

**Reason for Upgrade**:
To achieve real-time vision processing, the hardware needed a massive injection of parallel compute elements to process more output channels simultaneously per cycle.

---

## 2. TinyNPU2k / TinyNPU2k200J (The Compute Expansion)
**Architecture**: 20x8 Systolic Array (160 INT8 MACs)
**Target Clock**: 195 - 200 MHz
**Peak Compute**: ~31.2 GOPS (Theoretical)

**Advantages**:
- **Massive Parallelism**: A 2.5x increase in compute density. Processing 20 channels concurrently exponentially sped up depthwise and pointwise convolutions.
- **DSP Utilization**: Squeezed maximum value out of the Zynq-7020 silicon by utilizing 160 of the available 220 DSP48 slices.

**Disadvantages (The Reality Check)**:
- **Routing Catastrophe**: Packing 160 DSP48 blocks into the older 28nm Zynq fabric caused massive wire congestion. 
- **Lethal Timing Failures**: At 195 MHz (5.12ns clock period), the physical distance signals had to travel between the tightly packed DSPs caused severe Worst Negative Slack (WNS) violations (dropping well below -1.0ns).
- **Combinatorial Explosions**: The original shallow 2-stage PE pipeline and unpipelined math units physically could not resolve arithmetic logic fast enough within 5 nanoseconds.

**Reason for Upgrade**:
The design was physically unroutable on the Zynq-7020 (-1 speed grade) at 200 MHz. A strategic architectural pivot was required to balance maximum compute utilization with physically achievable clock frequencies.

---

## 3. TinyNPU200 (The Pipelining Phase)
**Architecture**: 20x8 Systolic Array 
**Target Clock**: 142 MHz (later scaled to 125 MHz)

**Advantages**:
- **Saner Clock Target**: Dropping the clock to the 125-142 MHz range gave the Vivado router breathing room (~7.0ns - 8.0ns periods).
- **Deep Pipelining Introduced**: We expanded the Processing Elements from a 2-stage to a 3-stage pipeline to break up the dense MAC logic.

**Disadvantages**:
- **Hidden Bottlenecks**: While the PEs passed timing, the deeper implementation revealed secondary and tertiary critical paths in the peripheral math units.
- Specifically, the **Depthwise Line Buffer Multipliers** (a 17-level DSP-to-Fabric path) and the **Requantization Unit** (a 20-level INT32 65-bit addition and barrel shift) crashed the router, resulting in `WNS = -0.790 ns`.

**Reason for Upgrade**:
The NPU core was fast, but the surrounding dataflow logic wasn't deep enough to support the throughput. We had to surgically bisect these specific mathematical bottlenecks without destroying the cycle-accurate handshaking of the AXI Stream.

---

## 4. TinyNPU200J (The Final, Perfected Silicon)
**Architecture**: 20x8 Systolic Array (160 INT8 MACs)
**Final Locked Clock**: 125.000 MHz (8.000ns period)
**Final Compute**: 20.0 GOPS (100% Timing Clean)

**Advantages (The Triumphs)**:
- **Flawless Timing Closure**: Achieved `WNS = +0.204 ns`. The design is 100% physically stable on the Zynq-7020.
- **Surgical RTL Pipelining**:
  - *Depthwise Multipliers*: Explicitly pipelined the 8x8 MAC units, slicing the DSP-to-Fabric adder path into two clean stages.
  - *Requantizer*: Bisected the lethal 65-bit addition and variable arithmetic right-shift into two separate registers (`pre_shift` and `shifted_result`).
- **Throughput Preserved**: Because the entire NPU uses valid-flag dataflow, deepening the pipeline stages added exactly 2 clock cycles (16 nanoseconds) of total end-to-end latency, preserving 100% of the massive 20 GOPS throughput.
- **Clean CDC constraints**: Added explicit `set_false_path` constraints to safely ignore the asynchronous 200 MHz HDMI pixel clock crossings.

**Conclusion**:
The **TinyNPU200J** represents the absolute physical limit of what can be gracefully packed and routed onto a Zynq-7020 FPGA while maintaining strict, production-ready timing closure. It perfectly balances extreme DSP utilization with carefully architected pipeline depths.
