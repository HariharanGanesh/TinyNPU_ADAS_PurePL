open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]

# Connect the NPU's output stream back to the DMA's S2MM port to prevent logic sweeping
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] -boundary_type upper
connect_bd_net [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk]

save_bd_design
generate_target all [get_files *.bd]

reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
