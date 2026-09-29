# fix_sysclk_freq.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

# Sync the external port frequency with the MMCM input frequency
set_property -dict [list CONFIG.FREQ_HZ {125000000}] [get_bd_ports sysclk]

save_bd_design

# Relaunch bitstream
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

open_run impl_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_FINAL_ROUTED_Timing.rpt"
exit
