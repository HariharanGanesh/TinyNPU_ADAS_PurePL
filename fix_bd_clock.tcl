open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
open_bd_design RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd
disconnect_bd_net /clk_wiz_0_clk_out1 [get_bd_pins tinynpu_0/aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins tinynpu_0/aclk]
save_bd_design
validate_bd_design
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
set_property synth_checkpoint_mode None [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
close_project