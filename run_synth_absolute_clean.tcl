open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
