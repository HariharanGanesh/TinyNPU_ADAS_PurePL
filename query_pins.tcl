open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1
puts "--- NPU PINS ---"
puts [join [get_pins npu_system_i/tinynpu_0/*] \n]
puts "--- DONE ---"
