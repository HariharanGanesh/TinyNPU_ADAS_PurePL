# Open the project
open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design "D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd"

# Delete the dangling DMA
delete_bd_objs [get_bd_cells axi_dma_0]

# Fix the TDATA width mismatch for Video In -> NPU
disconnect_bd_intf_net [get_bd_intf_nets vid_in_video_out] [get_bd_intf_pins vid_in/video_out]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 subconv_in
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES.VALUE_SRC USER CONFIG.M_TDATA_NUM_BYTES.VALUE_SRC USER] [get_bd_cells subconv_in]
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {3} CONFIG.M_TDATA_NUM_BYTES {4}] [get_bd_cells subconv_in]
connect_bd_intf_net [get_bd_intf_pins vid_in/video_out] [get_bd_intf_pins subconv_in/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins subconv_in/M_AXIS] [get_bd_intf_pins tinynpu_0/s_axis]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins subconv_in/aclk]
connect_bd_net [get_bd_pins rst_ps7_125M/peripheral_aresetn] [get_bd_pins subconv_in/aresetn]

# Fix the TDATA width mismatch for NPU -> Video Out
disconnect_bd_intf_net [get_bd_intf_nets tinynpu_0_m_axis] [get_bd_intf_pins tinynpu_0/m_axis]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 subconv_out
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES.VALUE_SRC USER CONFIG.M_TDATA_NUM_BYTES.VALUE_SRC USER] [get_bd_cells subconv_out]
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {4} CONFIG.M_TDATA_NUM_BYTES {3}] [get_bd_cells subconv_out]
connect_bd_intf_net [get_bd_intf_pins tinynpu_0/m_axis] [get_bd_intf_pins subconv_out/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins subconv_out/M_AXIS] [get_bd_intf_pins vid_out/video_in]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins subconv_out/aclk]
connect_bd_net [get_bd_pins rst_ps7_125M/peripheral_aresetn] [get_bd_pins subconv_out/aresetn]

# Validate, save, and launch bitstream generation
validate_bd_design
save_bd_design
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "================================================="
puts " AUTO-FIX COMPLETE AND BITSTREAM GENERATED!"
puts "================================================="
