open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
