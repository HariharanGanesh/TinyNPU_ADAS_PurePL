open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
exit