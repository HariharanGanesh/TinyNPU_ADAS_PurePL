open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
open_bd_design "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"
set master_intfs [get_bd_intf_pins -of_objects [get_bd_cells riscv_adas_0] -filter {MODE == Master}]
puts "Master Interfaces on riscv_adas_0: \"
exit