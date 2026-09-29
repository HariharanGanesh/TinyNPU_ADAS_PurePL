open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog
upgrade_ip [get_ips npu_system_tinynpu_0_0]
disconnect_net -net clk_wiz_0_clk_out1 -objects [get_pins tinynpu_0/aclk]
connect_net -net clk_wiz_0_clk_out2 [get_pins tinynpu_0/aclk]
save_bd_design
validate_bd_design
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
open_run impl_1
report_power -file Reports/power_report.txt
report_timing_summary -file Reports/timing_report.txt
report_utilization -file Reports/utilization_report.txt
close_project