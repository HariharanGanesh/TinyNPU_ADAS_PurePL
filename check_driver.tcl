open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1
puts "--- M_AXIS_TDATA DRIVER ---"
set driver [get_nets -of_objects [get_pins npu_system_i/tinynpu_0/m_axis_tdata[0]]]
puts "Net: $driver"
if {$driver != ""} {
    puts "Driven by: [get_pins -of_objects $driver -filter {DIRECTION == OUT}]"
}
puts "--- DONE ---"
