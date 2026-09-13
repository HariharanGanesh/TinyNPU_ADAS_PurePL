# cleanup_bd.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

# 1. Delete floating DDR and FIXED_IO ports left over from Zynq PS7
catch {delete_bd_objs [get_bd_ports DDR]}
catch {delete_bd_objs [get_bd_ports FIXED_IO]}

# 2. Delete the old Zynq AXI Interconnect that drove the VTC
catch {delete_bd_objs [get_bd_cells ps7_axi_periph]}

# 3. Delete the old floating external safety pins
catch {delete_bd_objs [get_bd_ports out_warning_ped]}
catch {delete_bd_objs [get_bd_ports out_warning_lane]}
catch {delete_bd_objs [get_bd_ports out_warning_sign]}
catch {delete_bd_objs [get_bd_ports out_brake_authorized]}
catch {delete_bd_objs [get_bd_ports out_system_fault]}

# 4. Connect the floating sw_brake_arm switch to the RISC-V
catch {connect_bd_net [get_bd_ports sw_brake_arm] [get_bd_pins riscv_adas_0/sw_brake_arm]}

# 5. Disable AXI-Lite on the Video Timing Controller (VTC) so it auto-starts without needing ARM/RISC-V initialization
set_property -dict [list CONFIG.enable_axi4_lite {false}] [get_bd_cells vtc]

# 6. Re-route the VTC clocks (since its AXI clock was removed)
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins vtc/clk]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins vtc/resetn]}

# 7. Tidy up the block design layout
regenerate_bd_layout
validate_bd_design
save_bd_design
