# resume_route.tcl
set dcp_file {D:/Final year project/npu200jpmax/npu200jpmax.runs/impl_1/npu_system_wrapper_physopt.dcp}
set out_dir  {D:/Final year project/npu200jpmax/npu200jpmax.runs/impl_1}
open_checkpoint $dcp_file
route_design -directive AggressiveExplore
write_checkpoint -force $out_dir/npu_system_wrapper_routed.dcp
report_timing_summary -file $out_dir/post_route_timing.rpt
report_utilization -file $out_dir/post_route_util.rpt
write_bitstream -force $out_dir/npu_system_wrapper.bit
puts {INFO: DONE - bitstream written!}
