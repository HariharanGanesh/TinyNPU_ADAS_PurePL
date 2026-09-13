import os
import re

rtl_dir = r"D:\Final year project\rtl"

# 1. Update axis_source.v
with open(os.path.join(rtl_dir, "axi", "axis_source.v"), "r") as f:
    src = f.read()
src = src.replace("parameter DATA_WIDTH      = 8", "parameter AXIS_DATA_WIDTH = 32,\n    parameter DATA_WIDTH      = 8")
src = src.replace("output reg  [DATA_WIDTH-1:0]   m_axis_tdata", "output reg  [AXIS_DATA_WIDTH-1:0]   m_axis_tdata")
src = src.replace("m_axis_tdata <= latch_word[next_byte_idx * DATA_WIDTH +: DATA_WIDTH];", "m_axis_tdata <= latch_word[next_byte_idx * AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];")
src = src.replace("m_axis_tdata  <= latch_word[byte_idx * DATA_WIDTH +: DATA_WIDTH];", "m_axis_tdata  <= latch_word[byte_idx * AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];")
src = src.replace("byte_idx == NUM_CHANNELS - 1", "byte_idx == (NUM_CHANNELS * DATA_WIDTH / AXIS_DATA_WIDTH) - 1")
src = src.replace("next_byte_idx == NUM_CHANNELS - 1", "next_byte_idx == (NUM_CHANNELS * DATA_WIDTH / AXIS_DATA_WIDTH) - 1")
with open(os.path.join(rtl_dir, "axi", "axis_source.v"), "w") as f:
    f.write(src)

# 2. Update tinynpu_top.v
with open(os.path.join(rtl_dir, "top", "tinynpu_top.v"), "r") as f:
    top = f.read()
top = top.replace("parameter DATA_WIDTH      = 8,", "parameter AXIS_DATA_WIDTH = 32,\n    parameter DATA_WIDTH      = 8,")
top = top.replace("input  wire [DATA_WIDTH-1:0]        s_axis_tdata", "input  wire [AXIS_DATA_WIDTH-1:0]   s_axis_tdata")
top = top.replace("output wire [DATA_WIDTH-1:0]        m_axis_tdata", "output wire [AXIS_DATA_WIDTH-1:0]   m_axis_tdata")

top = top.replace(".DATA_WIDTH(DATA_WIDTH)", ".AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),\n        .DATA_WIDTH(DATA_WIDTH)")

# Fix activation buffer generation
old_act_gen = """    genvar ch;
    generate
        for (ch = 0; ch < ARRAY_ROWS; ch = ch + 1) begin : gen_act_buf
            // Channel interleaving: byte addr[2:0] selects the channel bank
            wire ch_wr_en;
            assign ch_wr_en = stream_act_wr_en &&
                              (stream_act_wr_addr[2:0] == ch[2:0]);

            activation_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .BUFFER_DEPTH(BUFFER_DEPTH / ARRAY_ROWS),
                .ADDR_WIDTH(BUFFER_ADDR_WIDTH - 3)
            ) u_act_buf (
                .clk(clk), .rst_n(rst_n),
                .wr_addr(stream_act_wr_addr[BUFFER_ADDR_WIDTH-1:3]),
                .wr_data(stream_act_wr_data),
                .wr_en(ch_wr_en),"""

new_act_gen = """    genvar ch;
    generate
        for (ch = 0; ch < ARRAY_ROWS; ch = ch + 1) begin : gen_act_buf
            // Channel interleaving for 32-bit AXI-Stream
            wire ch_wr_en;
            assign ch_wr_en = stream_act_wr_en &&
                              ((stream_act_wr_addr[2:0] & 3'b100) == (ch[2:0] & 3'b100));
            wire [DATA_WIDTH-1:0] ch_wr_data;
            assign ch_wr_data = stream_act_wr_data[(ch[1:0])*8 +: 8];

            activation_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .BUFFER_DEPTH(BUFFER_DEPTH / ARRAY_ROWS),
                .ADDR_WIDTH(BUFFER_ADDR_WIDTH - 3)
            ) u_act_buf (
                .clk(clk), .rst_n(rst_n),
                .wr_addr(stream_act_wr_addr[BUFFER_ADDR_WIDTH-1:3]),
                .wr_data(ch_wr_data),
                .wr_en(ch_wr_en),"""

top = top.replace(old_act_gen, new_act_gen)
with open(os.path.join(rtl_dir, "top", "tinynpu_top.v"), "w") as f:
    f.write(top)

# 3. Update wrappers
for wrapper_path in [os.path.join(rtl_dir, "wrappers", "asic", "tinynpu_asic_wrapper.v"), os.path.join(rtl_dir, "wrappers", "fpga", "tinynpu_fpga_wrapper.v")]:
    with open(wrapper_path, "r") as f:
        wrap = f.read()
    wrap = wrap.replace("parameter DATA_WIDTH     = 8", "parameter AXIS_DATA_WIDTH = 32,\n    parameter DATA_WIDTH     = 8")
    wrap = wrap.replace("input  wire [DATA_WIDTH-1:0]       s_axis_tdata", "input  wire [AXIS_DATA_WIDTH-1:0]  s_axis_tdata")
    wrap = wrap.replace("output wire [DATA_WIDTH-1:0]       m_axis_tdata", "output wire [AXIS_DATA_WIDTH-1:0]  m_axis_tdata")
    wrap = wrap.replace(".DATA_WIDTH(DATA_WIDTH)", ".AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),\n        .DATA_WIDTH(DATA_WIDTH)")
    with open(wrapper_path, "w") as f:
        f.write(wrap)

# 4. Create Tcl script for TinyNPU2k project
tcl_script = '''# =============================================================================
# build_tinynpu2k.tcl
# Builds the 32-bit TinyNPU2k System
# =============================================================================

set ROOT_DIR    "D:/Final year project"
set RTL_DIR     "\/rtl"
set IP_DIR      "\/TinyNPUIP2k"
set SYS_DIR     "\/tinyNPU2k"
set SYS_NAME    "tinyNPU2k_system"
set PART        "xc7z020clg400-1"

puts "============================================================"
puts " Building TinyNPU2k System (32-bit AXI-Stream)"
puts "============================================================"

# Close any open project
close_project -quiet

# 1. Create temporary IP packaging project
file delete -force "\/tmp_ip_proj"
create_project tmp_ip_proj "\/tmp_ip_proj" -part \

# Add all RTL sources
add_files "\"
update_compile_order -fileset sources_1
set_property top tinynpu_top [current_fileset]

# Package IP
ipx::package_project -root_dir \ -vendor user.org -library user -taxonomy /UserIP -import_files
set_property name tinynpu_top [ipx::current_core]
set_property vendor_display_name "TinyNPU2k" [ipx::current_core]
set_property description "TinyNPU 32-bit INT8 AI Accelerator" [ipx::current_core]
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0  [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

# 2. Create the final system project
if {[file exists "\"]} { file delete -force \ }
create_project \ \ -part \

# Set IP Repo
set_property ip_repo_paths \ [current_project]
update_ip_catalog

# 3. Create Block Design
create_bd_design "\_bd"
open_bd_design [get_files \_bd.bd]

# Zynq PS
set zynq [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {150} CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] \

# AXI Interconnects
set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] \
set hp0_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 hp0_ic]
set_property -dict [list CONFIG.NUM_SI {1}] \

# DMA
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
# Note: Stream Data Width is now 32 bits!
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_m_axi_mm2s_data_width {32} CONFIG.c_m_axis_mm2s_tdata_width {32} CONFIG.c_m_axis_s2mm_tdata_width {32} CONFIG.c_include_mm2s {1} CONFIG.c_include_s2mm {1}] \

# TinyNPU2k
set npu [create_bd_cell -type ip -vlnv user.org:user:tinynpu_top:1.0 npu]

# Wire Clocks & Resets
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins ps7/S_AXI_HP0_ACLK] [get_bd_pins axi_ic/ACLK] [get_bd_pins axi_ic/S00_ACLK] [get_bd_pins axi_ic/M00_ACLK] [get_bd_pins axi_ic/M01_ACLK] [get_bd_pins dma/s_axi_lite_aclk] [get_bd_pins dma/m_axi_mm2s_aclk] [get_bd_pins dma/m_axi_s2mm_aclk] [get_bd_pins hp0_ic/aclk] [get_bd_pins npu/clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins axi_ic/ARESETN] [get_bd_pins axi_ic/S00_ARESETN] [get_bd_pins axi_ic/M00_ARESETN] [get_bd_pins axi_ic/M01_ARESETN] [get_bd_pins dma/axi_resetn] [get_bd_pins hp0_ic/aresetn] [get_bd_pins npu/rst_n]

# Wire AXI-Lite
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI] [get_bd_intf_pins dma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M01_AXI] [get_bd_intf_pins npu/s_axi]

# Wire AXI-Stream
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] [get_bd_intf_pins npu/s_axis]
connect_bd_intf_net [get_bd_intf_pins npu/m_axis] [get_bd_intf_pins dma/S_AXIS_S2MM]

# Wire HP0 & Interupt
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S] [get_bd_intf_pins hp0_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] [get_bd_intf_pins hp0_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_net [get_bd_pins dma/mm2s_introut] [get_bd_pins ps7/IRQ_F2P]

# Auto Assign Addresses
assign_bd_address

# Validate and Wrap
validate_bd_design
make_wrapper -files [get_files \_bd.bd] -top
add_files -norecurse "\/\.srcs/sources_1/bd/\_bd/hdl/\_bd_wrapper.v"
set_property top \_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Build Bitstream
puts "Starting Bitstream Generation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "Bitstream Generated for TinyNPU2k!"
'''

with open(r"D:\Final year project\build_tinynpu2k.tcl", "w") as f:
    f.write(tcl_script)

print("Done")
