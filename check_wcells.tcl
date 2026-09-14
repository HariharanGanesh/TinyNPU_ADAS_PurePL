open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_run synth_1

puts "--- U_WEIGHT_BUF CELLS ---"
set wcells [get_cells -hierarchical -filter {NAME =~ *u_weight_buf*}]
foreach cell $wcells {
    puts "Cell: $cell ([get_property REF_NAME $cell])"
}
puts "--- DONE ---"
