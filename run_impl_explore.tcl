open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
set_property strategy Performance_Explore [get_runs impl_1]
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1
puts "--- FULL GREEN IMPLEMENTATION DONE ---"
