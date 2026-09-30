# 1. Package the IP
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory IP/TinyNPU200/tmp IP/TinyNPU200/component.xml
update_compile_order -fileset sources_1
ipx::merge_project_changes files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project -delete

# 2. Open ADAS project
open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr

# 3. Upgrade IP in Block Design
update_ip_catalog
open_bd_design [get_files *.bd]
upgrade_bd_cells [get_bd_cells *tinynpu*] -quiet
upgrade_bd_cells [get_bd_cells *npu*] -quiet
validate_bd_design
save_bd_design

# 4. Launch Synthesis and Implementation
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

open_run impl_1
report_utilization -file adas_util_final.rpt
report_timing_summary -file adas_timing_final.rpt
report_power -file adas_power_final.rpt
