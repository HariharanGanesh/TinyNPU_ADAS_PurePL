# Rebuild IP and Synthesize
set ip_dir "D:/Final year project/IP/NPU300PM"
set bd_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

# 1. Update IP
open_project $bd_project
update_ip_catalog -rebuild

# 2. Package the modified IP
ipx::edit_ip_in_project -upgrade true -name edit_ip -directory C:/Temp $ip_dir/component.xml
ipx::current_core $ip_dir/component.xml
set_property core_revision [expr [get_property core_revision [ipx::current_core]] + 1] [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

# 3. Upgrade IP in BD (we are now back in npu200jpmax.xpr)
update_ip_catalog -rebuild
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips npu_system_tinynpu_0_0]

# 4. Generate Output Products
generate_target all [get_files "D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd"]

# 5. Launch Synthesis
reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1

puts "--- SYNTHESIS COMPLETE ---"
