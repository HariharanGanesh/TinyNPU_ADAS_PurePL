open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- DSP COUNT ---"
set dsps [get_cells -hierarchical -filter {REF_NAME =~ DSP48*}]
puts "Total DSPs: [llength $dsps]"

puts "--- BRAM COUNT ---"
set brams [get_cells -hierarchical -filter {REF_NAME =~ RAMB*}]
puts "Total BRAMs: [llength $brams]"

puts "--- NPU BRAMS ---"
set npu_brams [get_cells -hierarchical -filter {REF_NAME =~ RAMB* && NAME =~ *tinynpu*}]
puts "NPU BRAMs: [llength $npu_brams]"

puts "--- DONE ---"
