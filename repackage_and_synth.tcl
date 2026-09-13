set core [ipx::open_core "D:/Final year project/IP/NPU300PM/component.xml"]
ipx::merge_project_changes files $core
ipx::merge_project_changes hdl_parameters $core
set_property core_revision 3 $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
update_ip_catalog -rebuild -scan_changes
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips  npu_system_tinynpu_0_0]
generate_target all [get_ips npu_system_tinynpu_0_0]
export_ip_user_files -of_objects [get_ips npu_system_tinynpu_0_0] -no_script -sync -force -quiet
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
