# fix_mmcm_and_generate.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

# Tell the Clocking Wizard that the physical input clock from PYNQ-Z2 is 125 MHz (not 100)
# This allows it to calculate a valid VCO multiplier < 1200 MHz for Speed Grade -1
set_property -dict [list CONFIG.PRIM_IN_FREQ {125.000}] [get_bd_cells clk_wiz_0]

save_bd_design
reset_run synth_1

# Launch full synthesis and implementation
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

open_run impl_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_FINAL_ROUTED_Timing.rpt"

exit
