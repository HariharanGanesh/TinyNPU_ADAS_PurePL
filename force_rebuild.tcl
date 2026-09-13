open_project "D:/Final year project/npu200jb/npu200jb.xpr"
reset_run npu_system_tinynpu_0_0_synth_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
exit
