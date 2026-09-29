open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design {D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd}
set validate_result [validate_bd_design]
if {$validate_result != ""} {
    puts "BLOCK DESIGN VALIDATION RESULTS: $validate_result"
} else {
    puts "BLOCK DESIGN VALIDATION SUCCESSFUL. NO ERRORS OR WARNINGS."
}
close_project
exit
