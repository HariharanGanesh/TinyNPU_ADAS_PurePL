# generate_bitstream.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"

# Add the new ADAS physical constraints
add_files -fileset constrs_1 -norecurse "${proj_path}pynq_z2_adas.xdc"
set_property target_constrs_file "${proj_path}pynq_z2_adas.xdc" [current_fileset -constrset]

# Launch Implementation and Bitstream Generation
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Report final timing after physical routing
open_run impl_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_FINAL_ROUTED_Timing.rpt"

exit
