# TinyNPU200 Windows Deployment Guide

This guide provides step-by-step instructions to clone, build, and deploy the TinyNPU200 FPGA IP and RISC-V ADAS system on a Windows workstation.

## Prerequisites

1. **Operating System:** Windows 10 or 11 (64-bit)
2. **Tools:**
   - [Git for Windows](https://gitforwindows.org/)
   - **Xilinx Vivado 2025.1** (Ensure the Vivado in directory is in your system PATH, e.g., C:\Xilinx\Vivado\2025.1\bin)
   - Python 3.8+ (Optional, for running any custom analysis scripts)
3. **Hardware:**
   - PYNQ-Z2 Development Board (Zynq-7020)
   - Micro-USB cable (for JTAG programming & UART)

---

## 1. Access & Authorization

> **IMPORTANT:** This project contains proprietary IP. The RTL source files are not open-source.
Before cloning and using the project, you must ensure you have requested and been granted access.
Please review:
- [TERMS_OF_USE.md](TERMS_OF_USE.md)
- [ACCESS.md](ACCESS.md)

---

## 2. Clone the Repository

Open Command Prompt or PowerShell and clone the repository:

`cmd
git clone https://github.com/HariharanGanesh/TinyNPU_ADAS_PurePL.git
cd TinyNPU_ADAS_PurePL
`

---

## 3. Verify IP Packaging (Optional)

The TinyNPU200 IP is pre-packaged. If you have modified the RTL source files within IP/TinyNPU200/src/, you must repackage the IP before building the main project.

Run the provided Tcl script in Vivado batch mode:
`cmd
vivado -mode batch -source repack2.tcl
`
*This updates component.xml and ensures the Block Design uses the latest IP version.*

---

## 4. Verify the IP using Simulation

To run the functional verification testbench (which executes actual bit-accurate inference checks against the IP):

`cmd
vivado -mode batch -source run_sim2.tcl
`
Check the output for the NPU / IP VERIFICATION REPORT to ensure all tests report PASS.

---

## 5. Build the Project

You can build the complete System-on-Chip (SoC) project using the Vivado GUI.

1. Open Vivado 2025.1.
2. Click **Open Project** and navigate to:
   RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
3. In the Flow Navigator, click **Generate Bitstream**.
4. Wait for Synthesis and Implementation to complete. (This may take 5-15 minutes).

Alternatively, from the Vivado Tcl Console, you can run:
`	cl
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
`

---

## 6. Hardware Deployment

Since this is a **Pure PL** (Programmable Logic) design, there is no need for Vitis, ARM PS configuration, or a BOOT.bin on an SD card. You can program the FPGA directly over JTAG.

1. Connect your PYNQ-Z2 board via USB.
2. Ensure the boot jumper is set to **JTAG**.
3. Turn on the board.
4. In the Vivado GUI, open **Hardware Manager**.
5. Click **Auto Connect**.
6. Click **Program Device**.
7. Select the generated bitstream located at:
   RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.runs/impl_1/npu_system_wrapper.bit
8. Click **Program**.

The NPU and RISC-V controller are now running on the FPGA fabric!
