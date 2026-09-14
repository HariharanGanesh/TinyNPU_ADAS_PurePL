open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "================================================="
puts " BITSTREAM GENERATION COMPLETE!"
puts "================================================="
