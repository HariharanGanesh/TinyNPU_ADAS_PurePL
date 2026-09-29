open_project {D:/Final year project/tinynpu200_ip_packager/tinynpu200_ip_packager.xpr}

if {[llength [get_files *ooc_timing.xdc]] == 0} {
    add_files -fileset constrs_1 {D:/Final year project/ooc_timing.xdc}
}
set_property USED_IN {synthesis implementation out_of_context} [get_files *ooc_timing.xdc]

reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

reset_run impl_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1

open_run impl_1
report_timing_summary -file {D:/Final year project/timing_report.txt}
report_utilization -file {D:/Final year project/util_report.txt}

close_project
