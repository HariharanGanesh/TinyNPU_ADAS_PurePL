open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
reset_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -force
export_ip_user_files -of_objects [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -no_script -sync -force
create_ip_run [get_files -of_objects [get_fileset sources_1] RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
close_project