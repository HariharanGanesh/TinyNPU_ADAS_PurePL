# disable_ooc_and_generate.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"

# Reset ALL runs to clear any failed OOC states from previous batch crashes
foreach run [get_runs] {
    catch {reset_run $run}
}

# FORCE reset block design targets so Vivado actually applies the OOC disable command
reset_target all [get_files *.bd]
set_property synth_checkpoint_mode None [get_files *.bd]
generate_target all [get_files *.bd]

# Launch top-level synthesis and implementation
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

open_run impl_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_FINAL_ROUTED_Timing.rpt"
exit
