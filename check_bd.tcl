open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]
puts "--- BD CONNECTIONS ---"
set net [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]]
puts "DMA S2MM Net: $net"
if {$net != ""} {
    puts "Connected to: [get_bd_intf_pins -of_objects $net]"
}

set net2 [get_bd_intf_nets -of_objects [get_bd_intf_pins axis_broadcaster_0/M01_AXIS]]
puts "Broadcaster M01 Net: $net2"

puts "--- DONE ---"
