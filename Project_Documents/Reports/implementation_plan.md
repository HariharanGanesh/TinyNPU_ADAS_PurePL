# Pure-PL ASIC-Portable Architecture Migration

To make the chip 100% synthesizable in the Programmable Logic (PL) and fully portable to any FPGA or ASIC (completely removing the Zynq ARM Cortex-A9 dependency), we must fundamentally restructure the Block Design and Memory Map. The RISC-V PicoRV32 soft-core will be elevated to the **Sole System Master**.

## User Review Required

> [!WARNING]  
> Removing the ARM processor means we lose the ability to dynamically load Neural Network weights over Ethernet/Linux. The weights must either be pre-loaded into a massive PL ROM at synthesis time, or the RISC-V must read them from an external QSPI Flash / SD Card. 
> For this implementation, I propose we map the NPU weights to a fixed Block RAM (ROM) initialized at bitstream generation.

## Open Questions

> [!IMPORTANT]
> **RISC-V Toolchain:** To synthesize the C-firmware into the PL BRAM, it must be compiled into a `.hex` file. Do you have the `riscv32-unknown-elf-gcc` toolchain installed on your Windows machine, or should I write a Python-based RISC-V assembler to generate the machine code natively?

## Proposed Changes

---

### 1. Vivado Block Design Restructuring (`create_pure_pl_adas.tcl`)
We will write a new TCL script to aggressively rip out the Zynq specific IP and wire the RISC-V as the central brain.

#### [DELETE] `processing_system7_0` (ARM Cortex-A9)
#### [NEW] `clk_wiz_0` (PL MMCM)
- Driven directly by the 125 MHz physical board oscillator.
- Generates the `clk_fpga_0` (125 MHz) and `clk_fpga_1` (200 MHz) completely within the PL.

#### [MODIFY] AXI Interconnect Routing
- The PicoRV32 AXI Master will be routed into a 1-to-2 AXI Interconnect.
  - **Port 0**: Connects to the RISC-V 32KB BRAM (Memory Map: `0x00000000` to `0x00007FFF`).
  - **Port 1**: Connects to the TinyNPU CSR Slave (Memory Map: `0x40000000` to `0x4000FFFF`).

---

### 2. PicoRV32 Subsystem RTL Modifications

#### [MODIFY] [riscv_adas_subsystem.v](file:///D:/Final year project/IP/RISCV_ADAS_Controller/src/riscv_adas_subsystem.v)
- We will expose the AXI Memory Interface of the PicoRV32 to the top level so it can route out of the subsystem and talk to the NPU's CSRs. 
- Currently, the subsystem encapsulates its own BRAM. We will upgrade the internal interconnect to allow the RISC-V to reach external physical addresses.

---

### 3. Bare-Metal C-Firmware (`firmware.c`)

#### [NEW] [firmware.c](file:///D:/Final year project/IP/RISCV_ADAS_Controller/sw/firmware.c)
A strict, bare-metal C program that runs natively on the PicoRV32 out of PL BRAM.
- **NPU Initialization**: It will write to the AXI addresses `0x40000000` to configure the NPU's Activation Base, Weight Base, and DMA transfer sizes.
- **Trigger NPU**: It will write to the DMA Start register.
- **Safety Loop**: It will enter an infinite `while(1)` loop where it:
  1. Writes `0x5A5A5A5A` to the Hardware Watchdog.
  2. Reads the bounding box confidence scores from the NPU output BRAM.
  3. Evaluates ADAS logic and triggers physical brake interlocks if a collision is imminent.

## Verification Plan

### Automated Synthesis
- Execute the new TCL script to generate the pure-PL block design.
- Run Vivado Synthesis to guarantee WNS/WHS are green.

### Firmware Verification
- Compile `firmware.c` to `firmware.hex`.
- Use `$readmemh` in the BRAM Verilog model and run a behavioral simulation (Vivado XSIM) to prove the RISC-V successfully initializes the NPU over the AXI bus without ARM intervention.
