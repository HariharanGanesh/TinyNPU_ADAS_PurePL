open_checkpoint "D:/Final year project/npu200jpmax/npu200jpmax.runs/impl_1/npu_system_wrapper_routed.dcp"
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *u_csr/reg_crop_wh_reg[*]}] -to [get_cells -hierarchical -filter {NAME =~ *u_axis_sink/buf_wr_addr_reg[*]}]
report_timing_summary -max_paths 10
