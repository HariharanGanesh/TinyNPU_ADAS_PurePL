open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
ipx::open_core "D:/Final year project/IP/TinyNPU200/component.xml"
ipx::merge_project_changes hdl_parameters [ipx::current_core]
ipx::merge_project_changes files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
update_ip_catalog -rebuild -repo_path "D:/Final year project/IP/TinyNPU200"
upgrade_ip [get_ips npu_system_tinynpu_0_0]
reset_run synth_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1
puts "IMPLEMENTATION FINISHED!"
exit
