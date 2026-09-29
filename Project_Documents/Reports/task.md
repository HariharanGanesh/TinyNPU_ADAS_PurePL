# Pure-PL ADAS Subsystem Tasks

## 1. Toolchain & Firmware
- `[x]` Write `rv32_assembler.py` (a Python-based RV32I assembler).
- `[x]` Write `firmware.s` (RISC-V assembly for NPU initialization and watchdog).
- `[x]` Assemble `firmware.s` to `firmware.hex`.

## 2. RTL Modifications
- `[x]` Modify `riscv_adas_subsystem.v` to expose PicoRV32 AXI memory interface to the outside world.
- `[x]` Update BRAM logic inside `riscv_adas_subsystem.v` to use `$readmemh("firmware.hex", mem)`.

## 3. Vivado Integration
- `[x]` Restore deleted multiplier logic to TinyNPU Datapath Pipeline
- `[x]` Debug `status_busy` logic cascade failure in AXI Interconnect routing
- `[x]` Fix Digilent EDID IP VHDL file read cache extraction bug (Hardcoded absolute paths)
- `[x]` Generate fully routed, hardware-constrained `.bit` Bitstream File
- `[ ]` Document final synthesis bottlenecks (WNS = -1.794) and hardware performance metricsming.
