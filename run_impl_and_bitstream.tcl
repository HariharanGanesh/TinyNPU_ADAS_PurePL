open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"

puts "--- STARTING IMPLEMENTATION ---"
reset_run impl_1
launch_runs impl_1 -jobs 6
wait_on_run impl_1

puts "--- STARTING BITSTREAM GENERATION ---"
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "--- DONE ---"
exit
