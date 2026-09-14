open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- RAM32M CELLS ---"
set ram_cells [get_cells -hierarchical -filter {REF_NAME == RAM32M}]
foreach cell $ram_cells {
    puts "Cell: $cell"
}
puts "--- DONE ---"
