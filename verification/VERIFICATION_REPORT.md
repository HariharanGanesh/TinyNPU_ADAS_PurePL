# End-to-End HDMI Video Pipeline Verification Report

## 1. Pipeline Architecture & Clock Domains

`scii
+-------------------+        +-------------------+        +-------------------+
| HDMI RX (BFM)     |        | DVI2RGB PHY       |        | V_VID_IN_AXI4S    |
| (TMDS 10b/8b)     |=======>| (Native Video)    |=======>| (AXI4-Stream)     |
| CLK: 742.5 MHz    |        | CLK: 74.25 MHz    |        | CDC: 74.25->125   |
+-------------------+        +-------------------+        +-------------------+
                                                                   ||
                                                                   \/
+-------------------+        +-------------------+        +-------------------+
| RGB2DVI PHY       |        | V_AXI4S_VID_OUT   |        | TinyNPU & ADAS    |
| (TMDS 10b/8b)     |<=======| (Native Video)    |<=======| (AXI4-Stream)     |
| CLK: 742.5 MHz    |        | CDC: 125->74.25   |        | CLK: 125 MHz      |
+-------------------+        +-------------------+        +-------------------+
        ||                            ^^
        \/                            ||
+-------------------+        +-------------------+
| HDMI TX (Checker) |        | Video Timing Ctrl |
| (Native Video)    |        | (VTC) Sync Gen    |
| CLK: 74.25 MHz    |        | CLK: 74.25 MHz    |
+-------------------+        +-------------------+
`

### Clock Domain Crossings (CDCs)
1. **74.25 MHz (Pixel) -> 125 MHz (NPU Datapath):** Occurs inside the v_vid_in_axi4s block via an asynchronous FIFO.
2. **125 MHz (NPU Datapath) -> 74.25 MHz (Pixel):** Occurs inside the v_axi4s_vid_out block via an asynchronous FIFO.

## 2. Simulation Environment

* **Simulator:** Xilinx Vivado xsim 2023.2/2025.1
* **Command to Setup:** ivado -mode batch -source verification/scripts/setup_sim.tcl
* **Command to Run:** Open the Vivado GUI, select sim_hdmi_e2e, and hit Run Simulation. Alternatively, use xelab/xsim in batch mode.

## 3. Test Methodology

### SystemVerilog BFM
A custom SystemVerilog BFM (tb_hdmi_e2e.sv) was developed to drive the pipeline. Since simulating TMDS directly from scratch is highly complex, the BFM generates precise Native Video timing (720p60: 1650x750 total, 1280x720 active) and feeds it into an instantiated Digilent rgb2dvi IP block. This block acts as the HDMI source, generating the high-speed TMDS signals fed into the DUT's TMDS_RX pins. On the output side, a dvi2rgb IP block is instantiated to decode the DUT's TMDS_TX signals back into Native Video for scoreboard checking.

### Test Patterns
1. **Frame 0 (Gradient):** Ensures color channels (RGB) are correctly mapped.
2. **Frame 1 (Checkerboard):** High-frequency data toggling to test timing stability.
3. **Frame 2 (Corrupted Frame):** Injects a dropped line midway through the frame to test VTC/FIFO recovery.
4. **Frame 3 (Object Shape):** A solid white square on a black background.

## 4. Test Execution & Bug Triage

### Run 1: Execution Pending
* **Status:** IN PROGRESS (User action required)
* **Observation:** Simulating 4 full 720p frames at the TMDS serial clock rate (742.5 MHz) requires an extremely long simulation runtime (typically an overnight run). The infrastructure is complete, and the run must be executed on a high-performance workstation.

## 5. Known Limitations
1. **MMCM/PLL Lock Times:** The lock signals for the simulated PHY components assume an ideal lock behavior to expedite simulation of the large 720p frame sizes.
2. **HDMI Hot-plug Detect:** The rx_hpd and tx_hpd pins are driven to 1 (plugged in). Hot-plug removal and re-insertion sequences are not dynamically tested during active video streaming.
3. **Simulation Runtime:** Simulating multiple 720p frames through TMDS PHYs requires billions of delta cycles.

## 6. Verification Artifacts
* **Testbench:** verification/tb/tb_hdmi_e2e.sv
* **Setup Script:** verification/scripts/setup_sim.tcl
* **Result Logs:** Output logs will be saved to verification/sim_results/