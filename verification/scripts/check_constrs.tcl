open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts "CONSTRS FILES:"
foreach f [get_files -of_objects [get_filesets constrs_1]] {
    puts "FILE: $f (Exists: [file exists $f])"
}