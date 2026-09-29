open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- RST_N CONNECTION ---"
set rst_pin [get_pins npu_system_i/tinynpu_0/rst_n]
set rst_net [get_nets -of_objects $rst_pin]
puts "Pin: $rst_pin"
puts "Net: $rst_net"
if {$rst_net != ""} {
    puts "Driver: [get_pins -of_objects $rst_net -filter {DIRECTION == OUT}]"
} else {
    puts "UNCONNECTED!"
}
puts "--- DONE ---"
