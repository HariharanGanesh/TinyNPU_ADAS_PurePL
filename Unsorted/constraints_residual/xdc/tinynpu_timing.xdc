# TinyNPU Timing Constraints
# Target: Xilinx Spartan-7 XC7S50
# Target Frequency: 200 MHz (5 ns period)
#
# Notes:
#   - All TinyNPU logic should meet 200 MHz timing.
#   - The systolic array datapath (weight × act → accumulate) is the critical path.
#   - DSP48E1 blocks are pipelined — the registered MAC in the PE helps timing.
#   - AXI4-Lite control interface can be clocked at 100 MHz (half-rate) if needed.
#
# Board: Spartan-7 Evaluation Board (XC7S50-CSGA324-1)
# Adjust package/grade suffix as needed for your specific board.
# =============================================================================

# =============================================================================
# Primary Clock Constraint
# =============================================================================

# Main accelerator clock (200 MHz → 5.000 ns period)
create_clock -period 5.000 -name clk_main -waveform {0.000 2.500} [get_ports clk]

# If using separate AXI4-Lite control clock (100 MHz), uncomment:
# create_clock -period 10.000 -name clk_axi_lite -waveform {0.000 5.000} [get_ports aclk]

# =============================================================================
# Clock Uncertainty and Jitter
# =============================================================================

# Include clock uncertainty for MMCM jitter on Spartan-7
set_clock_uncertainty -setup 0.200 [get_clocks clk_main]
set_clock_uncertainty -hold  0.100 [get_clocks clk_main]

# =============================================================================
# Input/Output Delays (relative to clk_main)
# External interface delays — adjust for your board trace delays.
# =============================================================================

# AXI4-Lite inputs (generous margin for control path)
set_input_delay -clock clk_main -max 2.0 [get_ports {s_awaddr* s_awvalid s_wdata* s_wstrb* s_wvalid s_araddr* s_arvalid}]
set_input_delay -clock clk_main -min 0.5 [get_ports {s_awaddr* s_awvalid s_wdata* s_wstrb* s_wvalid s_araddr* s_arvalid}]

# AXI4-Lite outputs
set_output_delay -clock clk_main -max 2.0 [get_ports {s_awready s_wready s_bresp* s_bvalid s_arready s_rdata* s_rresp* s_rvalid}]
set_output_delay -clock clk_main -min 0.5 [get_ports {s_awready s_wready s_bresp* s_bvalid s_arready s_rdata* s_rresp* s_rvalid}]

# =============================================================================
# False Paths
# =============================================================================

# Soft reset path: asynchronous at chip level, need not meet tight timing
# set_false_path -from [get_ports rst_n]

# =============================================================================
# Multicycle Paths
# =============================================================================

# AXI4-Lite register reads: allow 2 cycles (read address → data valid)
# This is already handled by the registered read path in axi4_lite_slave.sv
# Uncomment if synthesis reports timing violations on CSR read path:
# set_multicycle_path -setup 2 -from [get_cells *axi4_lite_slave*/reg_*] -to [get_cells *axi4_lite_slave*/s_rdata*]

# =============================================================================
# Physical Constraints (Update for your specific FPGA board)
# =============================================================================

# Clock input pin — update LOC for your board's differential/single-ended clock
# Example for a common Spartan-7 dev board (Digilent Arty S7):
# set_property PACKAGE_PIN R2 [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset pin (active low)
# set_property PACKAGE_PIN C18 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# =============================================================================
# Timing Exceptions for Known Non-Critical Paths
# =============================================================================

# Performance cycle counter: large accumulator, can be multi-cycle
set_multicycle_path -setup 2 -to [get_cells -hierarchical -filter {NAME =~ *perf_cycle*}]
set_multicycle_path -hold  1 -to [get_cells -hierarchical -filter {NAME =~ *perf_cycle*}]

# =============================================================================
# Configuration Mode (for FPGA programming)
# =============================================================================
# set_property CONFIG_MODE SPIx4 [current_design]
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
