# TinyNPU200 IP Core Specification

## Architecture Overview
The TinyNPU200 is an FPGA-optimized Neural Processing Unit utilizing a 2D Systolic Array (20 rows x 8 cols) for accelerating quantized neural network inference. It is designed to operate on an AXI4 memory-mapped interface for weights and configuration, and AXI4-Stream interfaces for activations and outputs.

## Parameters and Hardware Limits
- **Precision**: 8-bit integer (INT8) activations and weights.
- **Systolic Array Dimensions**: 20 rows (compile-time fixed) x 8 cols.
- **Maximum Input Channels**: 65535.
- **Maximum Output Channels**: 65535.
- **Supported Activations**: Bypass, ReLU, HardSwish.
- **Supported Pooling**: MaxPool, AvgPool, Bypass (2x2 stride configured at runtime).

## Supported Interfaces
- **AXI4-Lite Slave**: For Control and Status Registers (CSRs). Implements strict protocol compliance (independent AW/W channel readiness).
- **AXI4 Memory Map Master**: For reading weights directly from external memory. 
- **AXI4-Stream Sink**: For receiving input activations continuously (tile-based).
- **AXI4-Stream Source**: For transmitting computed outputs (TLAST asserted on the final byte of the final word of each tile).

## Known Architectural Behaviors and Limitations
- **Clock Gating**: The module 	inynpu_icg.v is implemented as a pass-through (ssign clk_out = clk_in) for simulation stability. It does not actively perform dynamic power-saving clock gating.
- **Output Routing**: The DMA controller is dedicated exclusively to weight fetching. Output activations are solely transmitted via the AXI4-Stream source interface.
- **Static Dimensions**: The ARRAY_ROWS configuration is a compile-time synthesis parameter, not dynamically resizable at runtime, though it is exposed in the read-only CSRs for software discovery.

## Compliance and Verification
- Synthesized and implemented on Xilinx Zynq-7000 (xc7z020).
- Handshake-compliant independent AW/W AXI4-Lite CSR integration.
- End-to-end vector-verified using SystemVerilog functional simulation with bit-accurate cycle comparison.
