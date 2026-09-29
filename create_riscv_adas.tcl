# create_riscv_adas.tcl
set proj_path "D:/Final year project/"

# 1. Open existing project (from the X: drive alias)
open_project "${proj_path}npu200jpmax/npu200jb.xpr"

# 2. Save As to create the new project without disturbing the old one
save_project_as RISCV_ADAS_NPU300 "${proj_path}RISCV_ADAS_NPU300" -force

# 3. Add the new ADAS and RISC-V Verilog files
set src_path "${proj_path}IP/RISCV_ADAS_Controller/src"
add_files -fileset sources_1 [list \
  "${src_path}/picorv32.v" \
  "${src_path}/sensor_fusion.v" \
  "${src_path}/safety_unit.v" \
  "${src_path}/security_unit.v" \
  "${src_path}/riscv_adas_subsystem.v" \
]
update_compile_order -fileset sources_1

# 4. Open Block Design and add the RISC-V ADAS Subsystem
open_bd_design [get_files *.bd]

# Create module reference
create_bd_cell -type module -reference riscv_adas_subsystem riscv_adas_0

# 5. Wire up the clocks and reset (using the 125 MHz compute clock)
connect_bd_net [get_bd_pins riscv_adas_0/clk] [get_bd_pins rst_ps7_125M/slowest_sync_clk]
connect_bd_net [get_bd_pins riscv_adas_0/rst_n] [get_bd_pins rst_ps7_125M/peripheral_aresetn]

# 5.1 Disconnect ARM PS7 from NPU AXI (if connected) and connect RISC-V to NPU
catch {
    set old_net [get_bd_intf_nets -of_objects [get_bd_intf_pins tinynpu_0/s_axi]]
    delete_bd_objs $old_net
}
connect_bd_intf_net [get_bd_intf_pins riscv_adas_0/m_axi] [get_bd_intf_pins tinynpu_0/s_axi]

# 5.2 Map the new AXI connection in the Address Editor and remove the orphaned PS7 mapping
catch { exclude_bd_addr_seg [get_bd_addr_segs ps7/Data/SEG_tinynpu_0_reg0] }
assign_bd_address -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces riscv_adas_0/m_axi] [get_bd_addr_segs tinynpu_0/s_axi/reg0] -force

# 6. Make the physical safety I/O ports external
make_bd_pins_external  [get_bd_pins riscv_adas_0/sw_brake_arm]
set_property name sw_brake_arm [get_bd_ports sw_brake_arm_0]

make_bd_pins_external  [get_bd_pins riscv_adas_0/out_warning_ped]
set_property name out_warning_ped [get_bd_ports out_warning_ped_0]

make_bd_pins_external  [get_bd_pins riscv_adas_0/out_warning_lane]
set_property name out_warning_lane [get_bd_ports out_warning_lane_0]

make_bd_pins_external  [get_bd_pins riscv_adas_0/out_warning_sign]
set_property name out_warning_sign [get_bd_ports out_warning_sign_0]

make_bd_pins_external  [get_bd_pins riscv_adas_0/out_brake_authorized]
set_property name out_brake_authorized [get_bd_ports out_brake_authorized_0]

make_bd_pins_external  [get_bd_pins riscv_adas_0/out_system_fault]
set_property name out_system_fault [get_bd_ports out_system_fault_0]

# 7. Validate and save
validate_bd_design
save_bd_design

# 8. Update Wrapper
make_wrapper -files [get_files *.bd] -top
set wrapper_file "${proj_path}RISCV_ADAS_NPU300/RISCV_ADAS_NPU300.gen/sources_1/bd/npu_system/hdl/npu_system_wrapper.v"
add_files -norecurse [list "$wrapper_file"]
update_compile_order -fileset sources_1

# 9. Launch Synthesis (to check timing/errors)
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 10. Report timing
open_run synth_1 -name synth_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_Timing.rpt"
report_utilization -file "${proj_path}reports/RISCV_ADAS_Utilization.rpt"

exit
