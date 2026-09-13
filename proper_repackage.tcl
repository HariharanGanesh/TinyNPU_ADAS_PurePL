# 1. Create a dummy project in memory
create_project -in_memory -part xc7z020clg400-1

# 2. Add all NPU300PM source files
read_verilog [glob "D:/Final year project/IP/NPU300PM/src/*.v"]

# 3. Open the existing IP core
set core [ipx::open_core "D:/Final year project/IP/NPU300PM/component.xml"]

# 4. Merge the files from the current project into the IP core
ipx::merge_project_changes files $core
ipx::merge_project_changes ports $core
ipx::merge_project_changes hdl_parameters $core

# 5. Fix the clock interface (explicitly map aclk to clock and aresetn to reset)
set_property core_revision 4 $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core

# 6. Open the main project and upgrade the IP
open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
update_ip_catalog -rebuild -scan_changes
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips npu_system_tinynpu_0_0]

# 7. Re-run target generation and synthesis
open_bd_design [get_files *.bd]
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips npu_system_tinynpu_0_0] -no_script -sync -force -quiet

reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
