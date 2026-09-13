# TCL script to restore AXI DMA loopback and prevent DSP logic trimming
puts "================================================="
puts " RESTORING DMA LOOPBACK"
puts "================================================="

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

open_bd_design [get_files *npu_system.bd]

# 3. Add AXI DMA and AXI-Stream Broadcaster (if they don't already exist)
if {[get_bd_cells -quiet axi_dma_0] == ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
}
set_property -dict [list CONFIG.c_include_mm2s {0} CONFIG.c_sg_include_stscntrl_strm {0}] [get_bd_cells axi_dma_0]

if {[get_bd_cells -quiet axis_broadcaster_0] == ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0
}
set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells axis_broadcaster_0]

# 4. Delete the existing net connected to NPU m_axis
set old_net [get_bd_intf_nets -of_objects [get_bd_intf_pins tinynpu_0/m_axis]]
if {$old_net != ""} {
    delete_bd_objs $old_net
}

# 5. Route NPU output to Broadcaster
connect_bd_intf_net [get_bd_intf_pins tinynpu_0/m_axis] [get_bd_intf_pins axis_broadcaster_0/S_AXIS]

# 6. Route Broadcaster M00 to HDMI Subset Converter
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins subconv_out/S_AXIS]

# 7. Route Broadcaster M01 to AXI DMA (Loopback)
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# 8. Connect DMA AXI-Lite and AXI-Master using Auto-Routing
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/ps7/M_AXI_GP0} Slave {/axi_dma_0/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_S2MM} Slave {/ps7/S_AXI_HP0} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins ps7/S_AXI_HP0]

# Re-route the clocks for the Broadcaster
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins axis_broadcaster_0/aclk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins axis_broadcaster_0/aresetn]

validate_bd_design
save_bd_design

# 9. Force Global Synthesis and Relaunch Implementation
set_property synth_checkpoint_mode None [get_files npu_system.bd]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "================================================="
puts " BITSTREAM RE-GENERATED SUCCESSFULLY WITH DMA!"
puts "================================================="
