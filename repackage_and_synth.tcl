open_project IP/TinyNPU200/TinyNPU200.xpr
# Add all new verilog files
add_files [glob IP/TinyNPU200/src/*.v]
update_compile_order -fileset sources_1
ipx::open_ipxact_file IP/TinyNPU200/component.xml
ipx::merge_project_changes files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
# Update the BD project
open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild -repo_path "IP/TinyNPU200"
upgrade_ip [get_ips *tinynpu*]
reset_run npu_system_tinynpu_0_0_synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit