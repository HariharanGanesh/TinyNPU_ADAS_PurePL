# Full script to add DMA, disable SG, fix addressing, and run
puts "================================================="
puts " REBUILDING DMA LOOPBACK & RELAUNCHING"
puts "================================================="

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *npu_system.bd]

# 1. Add AXI DMA and AXI-Stream Broadcaster (if they don't already exist)
if {[get_bd_cells -quiet axi_dma_0] == ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
}
# Disable MM2S (Read) and Disable SG (Scatter-Gather) to remove unneeded clocks
set_property -dict [list CONFIG.c_include_mm2s {0} CONFIG.c_include_sg {0}] [get_bd_cells axi_dma_0]

if {[get_bd_cells -quiet axis_broadcaster_0] == ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0
}
set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells axis_broadcaster_0]

# 2. Delete the existing net connected to NPU m_axis
set old_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins tinynpu_0/m_axis]]
if {$old_net != ""} {
    delete_bd_objs $old_net
}

# 3. Route NPU output to Broadcaster
connect_bd_intf_net [get_bd_intf_pins tinynpu_0/m_axis] [get_bd_intf_pins axis_broadcaster_0/S_AXIS]

# 4. Route Broadcaster M00 to HDMI Subset Converter
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins subconv_out/S_AXIS]

# 5. Route Broadcaster M01 to AXI DMA (Loopback)
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# 6. Connect DMA AXI-Lite and AXI-Master using Auto-Routing
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/ps7/M_AXI_GP0} Slave {/axi_dma_0/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_S2MM} Slave {/ps7/S_AXI_HP0} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins ps7/S_AXI_HP0]

# 7. Ensure all clocks are connected
connect_bd_net -quiet [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins axis_broadcaster_0/aclk]
connect_bd_net -quiet [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins axis_broadcaster_0/aresetn]

# 8. Fix the excluded address space
set excluded_segs [get_bd_addr_segs -quiet -excluded -of_objects [get_bd_addr_spaces ps7/Data]]
foreach seg $excluded_segs {
    if {[string match "*axi_dma_0*" $seg]} {
        include_bd_addr_seg $seg
    }
}
assign_bd_address -quiet [get_bd_addr_segs {axi_dma_0/S_AXI_LITE/Reg}]
assign_bd_address -quiet [get_bd_addr_segs {ps7/S_AXI_HP0/HP0_DDR_LOWOCM}]

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
