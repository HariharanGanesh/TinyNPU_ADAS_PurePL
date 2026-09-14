open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr

# Check filesets
puts "Available constrs filesets: [get_filesets -filter {TYPE == Constrs}]"
set cset [current_fileset -constr]
puts "Current constrs fileset: $cset"

add_files -fileset $cset -norecurse {constraints/pynq_z2_customized.xdc}
add_files -norecurse {IP/TinyNPU200/src/dummy_weights.hex}

puts "Files in $cset: [get_files -of_objects [get_filesets $cset]]"
puts "Hex files: [get_files -filter {NAME =~ *.hex}]"