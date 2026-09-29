open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
open_bd_design {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}
set_property -dict [list   CONFIG.MMCM_DIVCLK_DIVIDE {1}   CONFIG.MMCM_CLKFBOUT_MULT_F {8.000}   CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000}   CONFIG.MMCM_CLKOUT1_DIVIDE {5}   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000}   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} ] [get_bd_cells clk_wiz_0]
validate_bd_design
save_bd_design
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
