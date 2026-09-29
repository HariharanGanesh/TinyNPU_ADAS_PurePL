open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- TINYNPU_0 CELLS ---"
set cells [get_cells -hierarchical -filter {NAME =~ *tinynpu_0/inst/*}]
foreach cell $cells {
    puts $cell
}
puts "--- DONE ---"
