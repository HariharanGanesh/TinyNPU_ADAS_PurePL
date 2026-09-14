open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts "=== CONSTRAINT FILES ==="
get_files -of_objects [get_filesets constrs_1]
puts "=== HEX FILES ==="
get_files -filter {NAME =~ *.hex}