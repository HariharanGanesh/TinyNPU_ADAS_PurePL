set core [ipx::open_core IP/TinyNPU200/component.xml]
ipx::update_checksums $core
ipx::save_core $core

open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild -repo_path "IP/TinyNPU200"
upgrade_ip [get_ips *tinynpu*]

generate_target all [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"] -force
reset_run npu_system_tinynpu_0_0_synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit