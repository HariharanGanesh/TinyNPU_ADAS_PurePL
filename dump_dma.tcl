open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

set pins [get_pins -of_objects [get_cells -hierarchical -filter {REF_NAME == dma_controller}]]
set f [open "D:/Final year project/dma_pins.txt" w]
foreach pin $pins {
    puts $f "Pin: $pin"
}
close $f
puts "--- DONE ---"
