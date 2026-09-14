open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"

# Disconnect the wrong 32-bit constant
disconnect_bd_net /xlconstant_0_dout [get_bd_ports rx_hpd]

# Delete the wrong port and create a new 1-bit port
delete_bd_objs [get_bd_ports rx_hpd]
create_bd_port -dir O -type data rx_hpd

# Create a 1-bit constant for HPD
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 hpd_const
set_property CONFIG.CONST_VAL 1 [get_bd_cells hpd_const]

# Connect it
connect_bd_net [get_bd_pins hpd_const/dout] [get_bd_ports rx_hpd]

save_bd_design
close_project
