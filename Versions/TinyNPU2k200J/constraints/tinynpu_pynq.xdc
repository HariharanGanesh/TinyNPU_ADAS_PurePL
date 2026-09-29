##############################################################################
# TinyNPU PYNQ-Z2 Timing and Clock-Domain Constraints
# File: tinynpu_pynq.xdc
#
# Vivado XDC (Xilinx Design Constraints) for the BUFGCE clock-gated design.
#
# HOW XDC CONSTRAINTS WORK:
#   Vivado uses an "SDC-like" language in .xdc files.
#   - create_clock  : defines a clock and its period for timing analysis.
#   - set_clock_groups: tells the timing engine which clocks can never have
#                      valid timing paths between them (asynchronous relationship).
#   - set_false_path : disables timing analysis on specific paths that are
#                      known to be safe (e.g., static configuration signals).
#
##############################################################################

##############################################################################
# 1. Primary Clock Definitions (PYNQ-Z2 uses 125 MHz system clock)
##############################################################################

# System clock from on-board 125 MHz oscillator via ZYNQ PS
# The NPU design is clocked at 150 MHz from a PL MMCM.
# Update the net name to match your Vivado block diagram MMCM output port.
create_clock -period 6.667 -name clk_npu [get_ports clk]

##############################################################################
# 2. Generated Clock Declarations for BUFGCE Gated Clocks
#    Vivado needs to know these are derived from clk_npu with the same period.
#    Without this, CDC analysis treats them as unrelated clocks.
##############################################################################

create_generated_clock \
    -name clk_compute \
    -source [get_ports clk] \
    -divide_by 1 \
    [get_pins u_cg_compute/u_bufgce/O]

create_generated_clock \
    -name clk_postproc \
    -source [get_ports clk] \
    -divide_by 1 \
    [get_pins u_cg_postproc/u_bufgce/O]

create_generated_clock \
    -name clk_dma \
    -source [get_ports clk] \
    -divide_by 1 \
    [get_pins u_cg_dma/u_bufgce/O]

##############################################################################
# 3. Clock Group Relationship
#    All four clocks are SYNCHRONOUS (same source, same period).
#    Vivado should analyze CDC paths between them as normal single-cycle paths.
#    Do NOT use set_clock_groups -asynchronous here — that would disable
#    timing analysis across clock domain crossings.
##############################################################################

# All gated clocks share the same master source — analysis is required
# across all combinations because data can flow from clk_compute to
# clk_postproc in back-to-back pipeline cycles.
# No set_clock_groups needed; default behaviour is correct.

##############################################################################
# 4. False Paths: CSR Configuration Signals
#    CSR registers (M0, n_shift, bias, crop, threshold, etc.) are written
#    by the ARM PS and are ONLY sampled by the PL when the NPU is IDLE.
#    Therefore there is no valid timing path from write to sample during
#    a computation — these can be safely set as false paths for the
#    purpose of MMCM output -> CSR register timing analysis.
#    (Normal intra-domain paths inside the PL are still fully analysed.)
##############################################################################

set_false_path -from [get_cells u_csr/reg_m0_reg*]        -to [get_cells u_requant/*]
set_false_path -from [get_cells u_csr/reg_n_shift_reg*]   -to [get_cells u_requant/*]
set_false_path -from [get_cells u_csr/reg_bias_reg*]      -to [get_cells u_requant/*]
set_false_path -from [get_cells u_csr/reg_conf_threshold_reg*] -to [get_cells u_threshold_filter/*]
set_false_path -from [get_cells u_csr/reg_crop_xy_reg*]   -to [get_cells u_axis_sink/*]
set_false_path -from [get_cells u_csr/reg_crop_wh_reg*]   -to [get_cells u_axis_sink/*]

##############################################################################
# 5. Reset False Path
#    rst_n is an asynchronous reset distributed to all domains.
#    The reset de-assertion is synchronised externally (PYNQ PS handles this).
##############################################################################

set_false_path -from [get_ports rst_n]

##############################################################################
# 6. BUFGCE Placement Guidance (Optional — Vivado usually handles this)
#    On Zynq-7000, BUFGCE resources are in the clock management tiles (CMT).
#    Uncomment and adapt if you get "No valid BUFGCE location" placement errors.
##############################################################################

# set_property LOC BUFGCE_X0Y0 [get_cells u_cg_compute/u_bufgce]
# set_property LOC BUFGCE_X0Y1 [get_cells u_cg_postproc/u_bufgce]
# set_property LOC BUFGCE_X0Y2 [get_cells u_cg_dma/u_bufgce]

##############################################################################
# 7. I/O Standards (PYNQ-Z2 uses LVCMOS33 on PL GPIO)
##############################################################################

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports interrupt]
