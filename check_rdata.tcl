open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- M_AXI_RDATA PINS ---"
set rdata_pins [get_pins -hierarchical -filter {NAME =~ *u_dma*rdata*}]
foreach pin $rdata_pins {
    puts "Pin: $pin"
    puts "  Net: [get_nets -of_objects $pin]"
    puts "  Driver: [get_pins -leaf -of_objects [get_nets -of_objects $pin] -filter {DIRECTION == OUT}]"
}
puts "--- DONE ---"
