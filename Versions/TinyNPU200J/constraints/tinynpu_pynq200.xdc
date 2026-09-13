##############################################################################
# tinynpu_pynq200.xdc - Timing & Clock-Domain Constraints for TinyNPU200
# Target: PYNQ-Z2 (XC7Z020CLG400-1)
#
# CLOCK ARCHITECTURE:
#   sys_pll   (MMCM #1):  125 MHz -> 125 MHz (clk_npu) + 200 MHz (IDELAYCTRL)
#   pixel_pll (MMCM #2):  125 MHz -> 74.286 MHz (clk_video, 720p pixel clock)
#
##############################################################################

##############################################################################
# 1. Primary Clock - 125 MHz System Clock
##############################################################################
create_clock -period 8.000 -name sys_clk -waveform {0.000 4.000} [get_ports sys_clk]

##############################################################################
# 2. Asynchronous Clock Groups
#    clk_out1_sys_pll (125 MHz) is ASYNCHRONOUS to u_pixel_pll/clkout0 (74.25 MHz)
##############################################################################
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk_out1_sys_pll] \
    -group [get_clocks -include_generated_clocks u_pixel_pll/clkout0]

##############################################################################
# 3. False Paths - CDC Boundaries & Configuration Registers
##############################################################################
# NPU -> Video CDC (cdc_async_fifo gray-code synchronizers)
# (Already covered by set_clock_groups, but explicitly re-stated for safety)
set_false_path -from [get_clocks clk_out1_sys_pll] -to [get_clocks u_pixel_pll/clkout0]
set_false_path -from [get_clocks u_pixel_pll/clkout0] -to [get_clocks clk_out1_sys_pll]

# CSR Configuration Registers (Written during IDLE, stable during execution)
set_false_path -from [get_cells u_npu/u_csr/reg_m0_reg*]               -to [get_cells u_npu/u_requant/*]
set_false_path -from [get_cells u_npu/u_csr/reg_n_shift_reg*]          -to [get_cells u_npu/u_requant/*]
set_false_path -from [get_cells u_npu/u_csr/reg_bias_reg*]             -to [get_cells u_npu/u_requant/*]
set_false_path -from [get_cells u_npu/u_csr/reg_conf_threshold_reg*]   -to [get_cells u_npu/u_threshold_filter/*]
set_false_path -from [get_cells u_npu/u_csr/reg_crop_xy_reg*]          -to [get_cells u_npu/u_axis_sink/*]
set_false_path -from [get_cells u_npu/u_csr/reg_crop_wh_reg*]          -to [get_cells u_npu/u_axis_sink/*]
set_false_path -from [get_cells u_npu/u_csr/reg_act_ext_reg*]          -to [get_cells u_npu/u_act/*]
set_false_path -from [get_cells u_npu/u_csr/reg_pool_mode_reg*]        -to [get_cells u_npu/u_pool/*]
set_false_path -from [get_cells u_npu/u_csr/reg_stride_sel_reg*]       -to [get_cells u_npu/u_ctrl/*]

# Reset False Path
set_false_path -from [get_ports sys_rst_n]

##############################################################################
# 4. MMCM Placement Constraints
##############################################################################
set_property LOC MMCME2_ADV_X1Y2 [get_cells u_rgb2dvi/U0/ClockGenInternal.ClockGenX/GenMMCM.DVI_ClkGenerator]
set_property LOC MMCME2_ADV_X0Y1 [get_cells u_pll/inst/mmcm_adv_inst]
set_property LOC MMCME2_ADV_X0Y0 [get_cells u_pixel_pll/inst/mmcm_adv_inst]

##############################################################################
# 5. BACKBONE Routing - sys_pll Input
##############################################################################
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets u_pll/inst/clk_in1_sys_pll]

##############################################################################
# 6. DONT_TOUCH - Prevent opt_design from trimming dvi2rgb reset logic
##############################################################################
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ u_dvi2rgb/*}]

##############################################################################
# 7. DRC Waiver - dvi2rgb pRst OOC synthesis trimming (cosmetic)
##############################################################################
set_property SEVERITY {WARNING} [get_drc_checks {NDRV-1}]

##############################################################################
# 8. I/O Standards - PL GPIO (LVCMOS33 on PYNQ-Z2)
##############################################################################
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

##############################################################################
# 9. Bitstream Version Annotation
##############################################################################
set_property BITSTREAM.CONFIG.USR_ACCESS 0x02000001 [current_design]
