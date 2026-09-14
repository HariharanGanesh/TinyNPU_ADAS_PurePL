open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]
puts "--- Broadcaster Interfaces ---"
get_bd_intf_pins -of_objects [get_bd_cells axis_broadcaster_0]
puts "--- Broadcaster Connections ---"
get_bd_intf_nets -of_objects [get_bd_cells axis_broadcaster_0]
puts "--- DMA S2MM Connections ---"
get_bd_intf_nets -of_objects [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
puts "--- DONE ---"
