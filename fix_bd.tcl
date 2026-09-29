open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog
open_bd_design RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd
upgrade_ip [get_ips npu_system_tinynpu_0_0]
disconnect_net -net clk_wiz_0_clk_out1 -objects [get_pins tinynpu_0/aclk]
connect_net -net clk_wiz_0_clk_out2 [get_pins tinynpu_0/aclk]
save_bd_design
validate_bd_design
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
set_property synth_checkpoint_mode None [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]
close_project