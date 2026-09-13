# fix_connections.tcl
set proj_path "X:/"
open_project "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

puts "Forcing disconnection of floating nets..."
# Disconnect all clocks/resets on axi_mem_intercon to purge old Zynq nets
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/ACLK]] [get_bd_pins axi_mem_intercon/ACLK]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/S00_ACLK]] [get_bd_pins axi_mem_intercon/S00_ACLK]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/M00_ACLK]] [get_bd_pins axi_mem_intercon/M00_ACLK]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/ARESETN]] [get_bd_pins axi_mem_intercon/ARESETN]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/S00_ARESETN]] [get_bd_pins axi_mem_intercon/S00_ARESETN]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_mem_intercon/M00_ARESETN]] [get_bd_pins axi_mem_intercon/M00_ARESETN]}

# Disconnect VTC clocks/resets
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins vtc/clk]] [get_bd_pins vtc/clk]}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins vtc/resetn]] [get_bd_pins vtc/resetn]}

puts "Routing PL clocks and resets..."
# Route Clocks
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/S00_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/M00_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins vtc/clk]

# Route Resets
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_mem_intercon/ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_mem_intercon/S00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_mem_intercon/M00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins vtc/resetn]

puts "Fixing safety ports..."
# Delete old or _0 ports
foreach p {out_warning_ped out_warning_lane out_warning_sign out_brake_authorized out_system_fault out_warning_ped_0 out_warning_lane_0 out_warning_sign_0 out_brake_authorized_0 out_system_fault_0} {
    catch {delete_bd_objs [get_bd_ports $p]}
}

# Delete any dangling nets for the safety pins
catch {delete_bd_objs [get_bd_nets riscv_adas_0_out_warning_ped]}
catch {delete_bd_objs [get_bd_nets riscv_adas_0_out_warning_lane]}
catch {delete_bd_objs [get_bd_nets riscv_adas_0_out_warning_sign]}
catch {delete_bd_objs [get_bd_nets riscv_adas_0_out_brake_authorized]}
catch {delete_bd_objs [get_bd_nets riscv_adas_0_out_system_fault]}

# Create new ports and connect them manually
create_bd_port -dir O out_warning_ped
connect_bd_net [get_bd_pins riscv_adas_0/out_warning_ped] [get_bd_ports out_warning_ped]

create_bd_port -dir O out_warning_lane
connect_bd_net [get_bd_pins riscv_adas_0/out_warning_lane] [get_bd_ports out_warning_lane]

create_bd_port -dir O out_warning_sign
connect_bd_net [get_bd_pins riscv_adas_0/out_warning_sign] [get_bd_ports out_warning_sign]

create_bd_port -dir O out_brake_authorized
connect_bd_net [get_bd_pins riscv_adas_0/out_brake_authorized] [get_bd_ports out_brake_authorized]

create_bd_port -dir O out_system_fault
connect_bd_net [get_bd_pins riscv_adas_0/out_system_fault] [get_bd_ports out_system_fault]

puts "Regenerating Layout..."
regenerate_bd_layout
validate_bd_design
save_bd_design
