open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
open_run synth_1 -name synth_1
report_utilization -file "D:/Final year project/RISCV_ADAS_PURE_PL/synth_utilization.txt"
puts "--- SYNTHESIS COMPLETE ---"