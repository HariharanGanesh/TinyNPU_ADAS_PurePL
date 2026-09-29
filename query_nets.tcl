open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files npu_system.bd]
puts "--- CLOCK NETS ---"
get_bd_nets -of_objects [get_bd_pins -filter {TYPE == clk}]
puts "--- RESET NETS ---"
get_bd_nets -of_objects [get_bd_pins -filter {TYPE == rst}]