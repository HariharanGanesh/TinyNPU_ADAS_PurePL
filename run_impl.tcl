open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit