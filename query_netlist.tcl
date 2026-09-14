# Query netlist
open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- DSP COUNT ---"
set dsps [get_cells -hierarchical -filter {REF_NAME == DSP48E1}]
puts "Total DSPs: [llength $dsps]"
foreach dsp $dsps {
    puts $dsp
}

puts "--- RAMB36 COUNT ---"
set brams [get_cells -hierarchical -filter {REF_NAME =~ RAMB36*}]
puts "Total BRAMs: [llength $brams]"

puts "--- TRACING MUL_S1 ---"
set mults [get_cells -hierarchical -filter {NAME =~ *mul_s1*}]
puts "Total mul_s1 cells: [llength $mults]"
