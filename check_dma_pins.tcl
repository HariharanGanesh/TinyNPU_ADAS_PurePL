open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- U_DMA PINS ---"
set dma_pins [get_pins -of_objects [get_cells npu_system_i/tinynpu_0/inst/u_dma]]
foreach pin $dma_pins {
    puts "Pin: $pin"
}
puts "--- DONE ---"
