open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set_property synth_checkpoint_mode None [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -force

reset_run synth_1
launch_runs synth_1 -scripts_only
exit