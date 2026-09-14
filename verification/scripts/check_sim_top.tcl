open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts "Active simulation fileset: [current_fileset -simset]"
puts "Top module in active simset: [get_property top [current_fileset -simset]]"