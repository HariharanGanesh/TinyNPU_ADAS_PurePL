open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild -scan_changes
upgrade_ip [get_ips npu_system_tinynpu_0_0]
save_bd_design
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "IMPL2 COMPLETE"