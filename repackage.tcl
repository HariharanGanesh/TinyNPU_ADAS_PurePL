create_project -in_memory -part xc7z020clg400-1
set_property source_mgmt_mode All [current_project]
add_files IP/TinyNPU200/src/
update_compile_order -fileset sources_1
ipx::package_project -root_dir IP/TinyNPU200 -vendor HariharanGanesh -library user -taxonomy /UserIP -import_files -set_current false
ipx::unload_core IP/TinyNPU200/component.xml
ipx::edit_ip_in_project -upgrade true -vlnv HariharanGanesh:user:tinynpu_top:1.0 IP/TinyNPU200/component.xml
ipx::current_core IP/TinyNPU200/component.xml
ipx::merge_project_changes files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild -repo_path "IP/TinyNPU200"
upgrade_ip [get_ips *tinynpu*]
reset_run npu_system_tinynpu_0_0_synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit