open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1
open_run impl_1 -name impl_1
report_timing_summary -file "D:/Final year project/RISCV_ADAS_PURE_PL/impl_timing.txt"
report_utilization -file "D:/Final year project/RISCV_ADAS_PURE_PL/impl_utilization.txt"
puts "--- IMPLEMENTATION & BITSTREAM COMPLETE ---"