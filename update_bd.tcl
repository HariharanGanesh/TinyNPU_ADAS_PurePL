open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
open_bd_design "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"

catch {delete_bd_objs [get_bd_cells axi_bram_ctrl_0]}
catch {delete_bd_objs [get_bd_cells blk_mem_gen_0]}
catch {delete_bd_objs [get_bd_cells xlconstant_1]}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list CONFIG.DATA_WIDTH {128} CONFIG.SINGLE_PORT_BRAM {1}] [get_bd_cells axi_bram_ctrl_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Use_RSTB_Pin {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Write_Rate {0} CONFIG.Port_B_Enable_Rate {100}] [get_bd_cells blk_mem_gen_0]

connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/riscv_adas_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_cas {0} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

connect_bd_net [get_bd_pins tinynpu_0/bram_clk] [get_bd_pins blk_mem_gen_0/clka]
connect_bd_net [get_bd_pins tinynpu_0/bram_rst] [get_bd_pins blk_mem_gen_0/rsta]
connect_bd_net [get_bd_pins tinynpu_0/bram_wr_en] [get_bd_pins blk_mem_gen_0/wea]
connect_bd_net [get_bd_pins tinynpu_0/bram_wr_addr] [get_bd_pins blk_mem_gen_0/addra]
connect_bd_net [get_bd_pins tinynpu_0/bram_wr_data] [get_bd_pins blk_mem_gen_0/dina]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1
set_property -dict [list CONFIG.CONST_VAL {1}] [get_bd_cells xlconstant_1]
connect_bd_net [get_bd_pins xlconstant_1/dout] [get_bd_pins blk_mem_gen_0/ena]

save_bd_design
validate_bd_design
exit