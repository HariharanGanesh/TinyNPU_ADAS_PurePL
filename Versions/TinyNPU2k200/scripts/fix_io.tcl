set proj_path "D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set proj_name [file rootname [file tail $proj_path]]
if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
    open_project "$proj_path"
} else {
    puts "  INFO: Project already open — skipping open_project"
}
open_bd_design {D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.srcs/sources_1/bd/tinynpu_system_bd/tinynpu_system_bd.bd}

puts "\n--- Deleting External Ports (Fixing IO Overutilization) ---"
set ext_ports [list enable_0 single_shot_0 frame_count_0 frame_done_0 det_bbox_x_0 det_bbox_y_0 det_bbox_w_0 det_bbox_h_0 det_confidence_0 det_valid_0]
foreach p $ext_ports {
    set port [get_bd_ports -quiet $p]
    if {$port ne ""} {
        delete_bd_objs $port
        puts "Deleted external port: $p"
    }
}

puts "\n--- Creating AXI GPIOs for PS Access ---"
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_ctrl
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_bbox1
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_bbox2
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_status
endgroup

# Configure GPIOs (Inputs to PL vs Outputs to PS)
set_property -dict [list CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_GPIO_WIDTH {2} CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells axi_gpio_ctrl]
set_property -dict [list CONFIG.C_ALL_INPUTS {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells axi_gpio_bbox1]
set_property -dict [list CONFIG.C_ALL_INPUTS {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells axi_gpio_bbox2]
set_property -dict [list CONFIG.C_ALL_INPUTS {1} CONFIG.C_GPIO_WIDTH {9}] [get_bd_cells axi_gpio_status]

puts "\n--- Running Connection Automation for AXI ---"
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_ctrl/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_ctrl/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_bbox1/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_bbox1/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_bbox2/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_bbox2/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_status/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_status/S_AXI]

puts "\n--- Connecting GPIOs to PL Logic ---"
# Slices for Control GPIO (2-bit output -> 1-bit enable, 1-bit single_shot)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice slice_enable
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice slice_single_shot
set_property -dict [list CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DIN_WIDTH {2} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_enable]
set_property -dict [list CONFIG.DIN_FROM {1} CONFIG.DIN_TO {1} CONFIG.DIN_WIDTH {2} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_single_shot]

connect_bd_net [get_bd_pins axi_gpio_ctrl/gpio_io_o] [get_bd_pins slice_enable/Din]
connect_bd_net [get_bd_pins axi_gpio_ctrl/gpio_io_o] [get_bd_pins slice_single_shot/Din]
connect_bd_net [get_bd_pins slice_enable/Dout] [get_bd_pins frame_gen_0/enable]
connect_bd_net [get_bd_pins slice_single_shot/Dout] [get_bd_pins frame_gen_0/single_shot]

connect_bd_net [get_bd_pins frame_gen_0/frame_count] [get_bd_pins axi_gpio_ctrl/gpio2_io_i]

# BBox Connections
connect_bd_net [get_bd_pins result_capture_0/det_bbox_x] [get_bd_pins axi_gpio_bbox1/gpio_io_i]
connect_bd_net [get_bd_pins result_capture_0/det_bbox_y] [get_bd_pins axi_gpio_bbox1/gpio2_io_i]
connect_bd_net [get_bd_pins result_capture_0/det_bbox_w] [get_bd_pins axi_gpio_bbox2/gpio_io_i]
connect_bd_net [get_bd_pins result_capture_0/det_bbox_h] [get_bd_pins axi_gpio_bbox2/gpio2_io_i]

# Status Connections
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat concat_status
set_property -dict [list CONFIG.IN0_WIDTH {1} CONFIG.IN1_WIDTH {8}] [get_bd_cells concat_status]
connect_bd_net [get_bd_pins result_capture_0/det_valid] [get_bd_pins concat_status/In0]
connect_bd_net [get_bd_pins result_capture_0/det_confidence] [get_bd_pins concat_status/In1]
connect_bd_net [get_bd_pins concat_status/dout] [get_bd_pins axi_gpio_status/gpio_io_i]

# Fix unconnected NPU reset
set rst_pin [get_bd_pins -quiet ps7/FCLK_RESET0_N]
if {$rst_pin eq ""} { set rst_pin [get_bd_pins -quiet processing_system7_0/FCLK_RESET0_N] }
if {$rst_pin ne ""} {
    connect_bd_net $rst_pin [get_bd_pins tinynpu100_0/rst_n]
}

puts "\n--- Rebuilding Design ---"
assign_bd_address -quiet
validate_bd_design
save_bd_design
make_wrapper -files [get_files tinynpu_system_bd.bd] -top -force
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "INFO: Generating bitstream in the background. Wait for completion!"
