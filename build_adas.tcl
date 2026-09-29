open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild -repo_path "D:/Final year project/IP/TinyNPU200"
upgrade_ip [get_ips npu_system_tinynpu_0_0] -log upgrade.log
reset_run synth_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1
puts "IMPLEMENTATION FINISHED!"
exit
