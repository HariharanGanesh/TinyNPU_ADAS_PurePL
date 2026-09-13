# TCL script to fix the BD errors and relaunch
puts "================================================="
puts " FIXING BD ERRORS AND RELAUNCHING"
puts "================================================="

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *npu_system.bd]

# 1. Disable Scatter-Gather on the DMA to remove m_axi_sg_aclk requirement
set_property -dict [list CONFIG.c_include_sg {0}] [get_bd_cells axi_dma_0]

# 2. Fix the excluded address space
set excluded_segs [get_bd_addr_segs -excluded -of_objects [get_bd_addr_spaces ps7/Data]]
foreach seg $excluded_segs {
    if {[string match "*axi_dma_0*" $seg]} {
        include_bd_addr_seg $seg
    }
}
assign_bd_address [get_bd_addr_segs {axi_dma_0/S_AXI_LITE/Reg}]
assign_bd_address [get_bd_addr_segs {ps7/S_AXI_HP0/HP0_DDR_LOWOCM}]

# Ensure all clocks are connected
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/ps7/FCLK_CLK0 (125 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]

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
