# Repackage the NPU300PM IP properly
set ip_dir "D:/Final year project/IP/NPU300PM"

# Open the IP project
open_project "$ip_dir/edit_TinyNPU_v1_0.xpr" -quiet
if {[get_projects -quiet] eq ""} {
    # If there isn't an edit project, just open the IP directly
    ipx::open_core "$ip_dir/component.xml"
} else {
    ipx::open_core "$ip_dir/component.xml"
}

# Force update ports from the top level module
ipx::merge_project_changes ports [ipx::current_core]
ipx::merge_project_changes hdl_parameters [ipx::current_core]

# Save and close
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::unload_core [ipx::current_core]
close_project

# Now open the main project, clear cache, upgrade IP and synthesize
open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild

# Upgrade the IP
set locked_ips [get_ips -filter {IS_LOCKED == 1}]
if {$locked_ips ne ""} {
    catch {upgrade_ip $locked_ips}
} else {
    # Force upgrade anyway if it's not locked but out of date
    catch {upgrade_ip [get_ips npu_system_tinynpu_0_0]}
}

# Clear IP cache
config_ip_cache -clear_local_cache
reset_target all [get_files *.bd]
generate_target all [get_files *.bd]

reset_run synth_1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
puts "--- ALL TASKS COMPLETE ---"
exit
