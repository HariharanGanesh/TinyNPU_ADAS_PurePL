open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
open_bd_design "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"
generate_target all [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"] -force
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit