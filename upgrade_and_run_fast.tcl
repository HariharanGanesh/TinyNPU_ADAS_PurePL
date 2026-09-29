open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
update_ip_catalog -rebuild
upgrade_ip [get_ips *tinynpu_0*]
generate_target all [get_files {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
