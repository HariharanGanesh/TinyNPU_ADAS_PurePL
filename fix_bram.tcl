open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
open_bd_design "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"
set_property -dict [list CONFIG.Write_Width_A {128} CONFIG.Read_Width_A {128} CONFIG.Write_Depth_A {1024}] [get_bd_cells blk_mem_gen_0]
save_bd_design
validate_bd_design
reset_run npu_system_blk_mem_gen_0_0_synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit