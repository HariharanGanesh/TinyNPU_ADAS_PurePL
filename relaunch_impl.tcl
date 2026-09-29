open_project "D:/Final year project/npu200jb/npu200jb.xpr"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
exit
