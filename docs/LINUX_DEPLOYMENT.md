# TinyNPU ADAS - Linux Deployment Guide

This guide provides instructions specific to deploying and building the TinyNPU ADAS project on a Linux development machine (e.g., Ubuntu/CentOS). 

While the FPGA bitstream generation itself is identical to Windows, Vivado on Linux requires specific environment setups and permissions for hardware programming.

---

## 🐧 1. Linux-Specific Advantages & Prerequisites

### Advantages of Linux for this Project
* **No Path Length Limits:** Unlike Windows, Linux does not have a 260-character path limit. You can clone the repository anywhere without worrying about Vivado OOC (Out-of-Context) IP build failures.
* **Faster Synthesis:** Vivado batch mode and synthesis jobs typically execute faster and utilize multi-core CPUs more efficiently in a Linux environment.

### Prerequisites
* **Supported OS:** Ubuntu 22.04 LTS / 24.04 LTS, CentOS, or RHEL.
* **Vivado:** Xilinx Vivado 2025.1 for Linux.

---

## 🛠️ 2. Environment Setup

Before launching Vivado or building the project, you must source the Vivado environment variables in your terminal. 

Assuming Vivado is installed in the default directory `/tools/Xilinx/`, run:

```bash
source /tools/Xilinx/Vivado/2025.1/settings64.sh
```
*(Tip: Add this line to your `~/.bashrc` to load it automatically on every new terminal session.)*

---

## 🔌 3. Cable Drivers & USB Permissions

By default, Linux restricts access to USB devices (like the JTAG programmer on the PYNQ-Z2). You must install the Xilinx cable drivers and configure `udev` rules.

### Install Cable Drivers
Navigate to the Vivado installation directory and run the installation script as root:
```bash
cd /tools/Xilinx/Vivado/2025.1/data/xicom/cable_drivers/lin64/install_script/install_drivers/
sudo ./install_drivers
```

### Add User to Dialout Group
To allow your user account to access the UART/JTAG interface without `sudo`, add yourself to the `dialout` group:
```bash
sudo usermod -a -G dialout $USER
```
**You must log out and log back in** (or reboot) for this group change to take effect.

---

## 🚀 4. Download Files and Build

You can download the project files from GitHub using either Git or a direct ZIP download.

### Option A: Using Git (Recommended)
Open your terminal and clone the repository to your preferred workspace:
```bash
git clone https://github.com/HariharanGanesh/TinyNPU_ADAS_PurePL.git
cd TinyNPU_ADAS_PurePL
```

### Option B: Using ZIP Download
If you do not have Git installed, you can download and extract the repository archive using `wget` and `unzip`:
```bash
# Download the ZIP file from GitHub
wget https://github.com/HariharanGanesh/TinyNPU_ADAS_PurePL/archive/refs/heads/main.zip -O TinyNPU_ADAS_PurePL.zip

# Extract the files
unzip TinyNPU_ADAS_PurePL.zip

# Navigate into the extracted directory
cd TinyNPU_ADAS_PurePL-main
```

### Option A: GUI Mode
Launch Vivado by typing:
```bash
vivado &
```
Then, go to **Open Project** and select `RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr`. Click **Generate Bitstream** in the Flow Navigator.

### Option B: Terminal / Batch Mode (Recommended)
To synthesize and generate the bitstream completely headless in the terminal (great for SSH servers), use the provided TCL scripts:

```bash
cd RISCV_ADAS_PURE_PL
vivado -mode batch -source ../run_pure_pl_impl.tcl
```
*Note: Make sure the TCL script paths are adjusted for your environment if they contain absolute paths.*

---

## 🎯 5. Programming the FPGA

Hardware setup (HDMI IN, HDMI OUT) remains exactly the same as described in the standard Quickstart Guide.

To program the board on Linux:
1. Turn on the PYNQ-Z2 board.
2. In the Vivado GUI, open the **Hardware Manager**.
3. Click **Auto Connect**. 
   *(If it fails to connect, verify your `udev` rules and `dialout` group from Step 3).*
4. Select `xc7z020_1`, click **Program Device**, and flash the `.bit` file located in:
   `RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.runs/impl_1/npu_system_wrapper.bit`

Your ADAS pipeline is now actively running in hardware!
