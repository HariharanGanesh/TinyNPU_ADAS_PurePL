open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts "Active fileset: [current_fileset -simset]"
puts "All sim filesets: [get_filesets -filter {TYPE == SimulationRun}]"