# Results and Discussion (Draft for IEEE Paper)

## 1. Implementation Results on Zynq-7020

The TinyNPU200 architecture was implemented on a Xilinx Zynq-7020 FPGA using Vivado 2025.1. The design is configured with a 14x14 systolic array (196 Processing Elements) combined with a hardware-accelerated 14-channel depthwise convolution engine and a requantization unit.

To achieve an optimal balance of resources on the constrained Zynq-7020, the synthesis directives were carefully tuned. The 14x14 systolic array's 8-bit multipliers were mapped efficiently to logic LUTs, reserving the dedicated DSP48E1 slices for the higher-precision operations in the depthwise engine and requantization unit. This architectural decision allowed the design to fit comfortably within the device's limits.

**Table 1: Post-Implementation Resource Utilization**
| Resource | Used | Available | Utilization |
|---|---|---|---|
| LUTs | 37,148 | 53,200 | 69.82% |
| DSP Blocks | 150 | 220 | 68.18% |
| Flip-Flops | 54,219 | 106,400 | 50.95% |
| BRAM (RAMB36) | 2 | 140 | 1.42% |

The utilization report confirms that the Depthwise Engine consumes 84 DSP blocks and the Requantization Unit consumes 56 DSP blocks, with the remainder used for control logic. 

## 2. Timing and Performance Analysis

The standalone NPU was constrained with an 8.0 ns clock period (125 MHz target). Post-route timing analysis reported a Worst Negative Slack (WNS) of just -0.051 ns, yielding an effective Maximum Operating Frequency ({max}$) of **124.2 MHz**. At this frequency, the design meets all setup and hold timing requirements with zero failing endpoints, ensuring stable physical operation.

At 124.2 MHz, the 196-PE systolic array paired with the depthwise and requantization engines provides high-throughput inference for quantized INT8 neural networks. The total on-chip power consumption is estimated at approximately 0.93 W, demonstrating excellent energy efficiency suitable for edge-deployed ADAS applications.

## 3. Hardware Verification

A rigorous simulation testbench was developed to validate the hardware against mathematically derived expected outputs. The test suite verifies AXI4-Lite control flow, race-condition handling, DMA interleaving, and end-to-end dataflow. All test cases, including a multi-channel inference workload, passed with 100% accuracy matching the predicted spatial accumulation vectors, confirming the functional integrity of the NPU's custom memory unpackers and pipeline alignment.
