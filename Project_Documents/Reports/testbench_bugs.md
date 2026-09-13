# TinyNPU Testbench Bug Report & Resolutions

During the verification phase of the `TinyNPU300PM` FPGA backend, several critical issues were discovered specifically within the **testbench environment and verification IPs** rather than the core NPU logic itself. 

A flawed testbench will either falsely pass a broken design or fail a working design. Below is a detailed breakdown of the testbench defects identified and how they were structurally resolved to achieve a reliable verification platform.

---

## 1. Scoreboard Port Mismatch and Parametrization

### The Bug
The hardware scoreboard (`hw_scoreboard.v`) used to validate the output AXI-Stream was incorrectly instantiated inside the top-level testbench (`tinynpu_top_tb.sv`). The testbench attempted to pass an `INIT_FILE` parameter and an `m_axis_tlast` signal that simply didn't exist on the scoreboard module. Furthermore, it mapped several statistical counters (like `pass_rate` and `detection_accuracy`) using the wrong port names and bit widths. 

This caused catastrophic elaboration failures where the Vivado simulator (`xelab`) refused to compile the testbench.

### The Fix
1. Removed the invalid `.INIT_FILE` and `.m_axis_tlast` bindings from the scoreboard instantiation.
2. Re-mapped the statistical ports to their correct names (`sb_precision_x100` and `sb_accuracy_x100` instead of `pass_rate` and `detection_accuracy`).
3. Corrected the signal declaration widths in the testbench from 8-bit to 16-bit to match the `hw_scoreboard` outputs, preventing precision truncation.

## 2. AXI-Stream Data Width Mismatch (The SVA Deadlock)

### The Bug
This was the most severe issue affecting the simulation. The NPU's `axis_sink` and activation buffer components were architecturally optimized to ingest a **32-bit** wide AXI-Stream (extracting 4 bytes per clock cycle to write to 4 memory banks simultaneously via channel interleaving). 

However, the testbench verification IP (`bram_sensor_emulator`) was hardcoded to emit an **8-bit** stream. Because the testbench instantiated the NPU using its default parameters (`AXIS_DATA_WIDTH = 32`), the NPU attempted to pull 32 bits from an 8-bit bus. The upper 24 bits were left floating (high-Z/`zz`), which corrupted the systolic arrays with `xx` logic values, stalled the controllers, and triggered a fatal SystemVerilog Assertion (SVA) deadlock after 10,000 cycles.

### The Fix
Instead of rewriting the entire sensor emulator verification IP to pack bytes, we fixed the interoperability at the NPU boundary:
1. Overrode `.AXIS_DATA_WIDTH(8)` explicitly in the `tinynpu_top` instantiation within `tinynpu_top_tb.sv`.
2. Restructured the channel interleaving logic in `tinynpu_top.v` using a `generate if (AXIS_DATA_WIDTH == 32) ... else ...` block. 
3. The RTL can now dynamically drop down to 1-byte per cycle writes for the 8-bit testbench streams, while retaining its optimized 4-byte/cycle mode for full 32-bit production compilation.

## 3. Buffer Address Width vs. Depth Misalignment

### The Bug
In the testbench parameters for the NPU, `BUFFER_DEPTH` was set to `512` but `BUFFER_ADDR_WIDTH` was set to `10`. Mathematically, a depth of 512 only requires 9 bits of addressing (`2^9 = 512`). An address width of 10 implies a depth of 1024. This caused formal slice mismatches when calculating the sub-bank write addresses for the activation buffers (resulting in warnings like *actual bit length 9 differs from formal bit length 7*).

### The Fix
Corrected the testbench instantiation to properly reflect `.BUFFER_ADDR_WIDTH(9)` alongside `.BUFFER_DEPTH(512)`, which aligned the memory slicing boundaries and cleared the compiler warnings.

## 4. Missing Timescale Directives

### The Bug
The simulator crashed during data flow analysis because some files possessed timing definitions while others didn't. Specifically, the Integrated Clock Gating module (`tinynpu_icg.v`) and the scoreboard (`hw_scoreboard.v`) lacked Verilog timescale directives, which is strictly prohibited when mixed with files that do.

### The Fix
Injected `` `timescale 1ns / 1ps `` directives at the top of the offending modules to align simulation step resolution across the entire NPU hierarchy.

## 5. Misplaced Memory Initialization Vectors (.hex)

### The Bug
The testbench successfully compiled, but the simulation crashed at Time 0 with `Fatal: Golden memory failed to load`. The `bram_sensor_emulator` and `hw_scoreboard` rely on reading `test_sensor_data.hex` and `golden_output.hex` using the `$readmemh` system task. These files were stored in `02_Verification/vectors/`, but the testbench execution directory (`02_Verification/tb/`) could not find them.

### The Fix
Copied the `.hex` stimulus vectors directly into the `tb/` execution root so they are natively available to the Vivado `xsim` runtime.
