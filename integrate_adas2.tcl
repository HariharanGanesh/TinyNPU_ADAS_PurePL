open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr

# Update catalog to detect changes to the IP source files
update_ip_catalog -rebuild

# Check status
report_ip_status -name ip_status

# Upgrade the IP if it's locked or modified
upgrade_ip [get_ips *npu*] -quiet
upgrade_ip [get_ips *TinyNPU*] -quiet

# Open BD and upgrade cells
open_bd_design [get_files *.bd]
upgrade_bd_cells [get_bd_cells *] -quiet
validate_bd_design
save_bd_design

# Launch Implementation
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

open_run impl_1
report_utilization -file adas_util_final.rpt
report_timing_summary -file adas_timing_final.rpt
report_power -file adas_power_final.rpt
