open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild
upgrade_ip [get_ips *dvi2rgb*]
reset_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
file delete -force RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.gen
file delete -force RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.ip_user_files
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -force
export_ip_user_files -of_objects [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -no_script -sync -force
close_project