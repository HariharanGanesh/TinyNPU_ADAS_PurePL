# =============================================================================
# create_hdmi_bd.tcl
# TinyNPU2k200J - Full HDMI Block Design Generator
# Automatically creates the Vivado Block Design connecting:
#   DVI2RGB (HDMI IN) -> TinyNPU IP -> OSD RTL -> RGB2DVI (HDMI OUT)
# =============================================================================

set ROOT_DIR   "D:/Final year project"
set SRC_DIR    "$ROOT_DIR/Versions/TinyNPU2k200J/rtl/src"
set DIG_IP_DIR "$ROOT_DIR/Shared/IP/digilent-vivado-library/ip"
set PROJ_DIR   "$ROOT_DIR/vivado_2k200j_proj"
set PROJ_NAME  "tinynpu_2k200j"
set PART       "xc7z020clg400-1"
set BD_NAME    "tinynpu_hdmi_system"

puts "============================================================"
puts " TinyNPU2k200J Block Design Generator"
puts "============================================================"

# Create Project
create_project -force $PROJ_NAME $PROJ_DIR -part $PART

# Add Digilent IP Repository
set_property ip_repo_paths [list \
    "$ROOT_DIR/Shared/IP/ip_repo" \
    $DIG_IP_DIR \
] [current_project]
update_ip_catalog -rebuild

# Add all RTL Source Files
add_files [glob $SRC_DIR/core/*.v]
add_files [glob $SRC_DIR/activation/*.v]
add_files [glob $SRC_DIR/axi/*.v]
add_files [glob $SRC_DIR/buffers/*.v]
add_files [glob $SRC_DIR/control/*.v]
add_files [glob $SRC_DIR/dma/*.v]
add_files [glob $SRC_DIR/dw_engine/*.v]
add_files [glob $SRC_DIR/pe/*.v]
add_files [glob $SRC_DIR/pooling/*.v]
add_files [glob $SRC_DIR/quantization/*.v]
add_files [glob $SRC_DIR/systolic_array/*.v]
add_files [glob $SRC_DIR/top/*.v]
add_files [glob $SRC_DIR/osd/*.v]
add_files [glob $SRC_DIR/test_wrappers/tinynpu_hdmi_top.v]

# Add HDMI Pin Constraints
add_files -fileset constrs_1 "$ROOT_DIR/Versions/TinyNPU2k200J/constraints/hdmi_pins.xdc"

# Set Top Module
set_property top tinynpu_hdmi_top [current_fileset]

# =============================================================================
# Create Block Design
# =============================================================================
create_bd_design $BD_NAME

# --- Clocking Wizard (195 MHz) ---
puts "\n--- Adding Clocking Wizard (195 MHz) ---"
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 sys_pll
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ       {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {195.000} \
    CONFIG.CLKOUT2_USED       {true}    \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.USE_LOCKED         {true}    \
    CONFIG.USE_RESET          {false}   \
] [get_bd_cells sys_pll]

# --- DVI2RGB (HDMI IN) ---
puts "\n--- Adding DVI2RGB (HDMI Input Decoder) ---"
create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:1.9 dvi2rgb_0
set_property -dict [list \
    CONFIG.kEEDID_ROM_EN {false} \
    CONFIG.kAddBUFG      {true}  \
] [get_bd_cells dvi2rgb_0]

# --- RGB2DVI (HDMI OUT) ---
puts "\n--- Adding RGB2DVI (HDMI Output Encoder) ---"
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
set_property -dict [list \
    CONFIG.kGenerateSerialClk {false} \
] [get_bd_cells rgb2dvi_0]

# --- AXI4-Stream Data Width Converter ---
puts "\n--- Adding AXI4-Stream Data Width Converter ---"
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_0
set_property -dict [list \
    CONFIG.S_TDATA_NUM_BYTES {3} \
    CONFIG.M_TDATA_NUM_BYTES {4} \
] [get_bd_cells axis_dwidth_0]

# --- AXI4-Stream Video Timing Controller ---
puts "\n--- Adding Video Timing Controller ---"
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 vtc_0
set_property -dict [list \
    CONFIG.enable_detection {false} \
    CONFIG.VIDEO_MODE       {1080p}  \
] [get_bd_cells vtc_0]

# =============================================================================
# Wire Block Design Connections
# =============================================================================
puts "\n--- Wiring Block Design ---"

# Board Ports
create_bd_port -dir I sys_clk
create_bd_port -dir I sys_rst_n

# HDMI RX Ports
create_bd_port -dir I    hdmi_rx_clk_p
create_bd_port -dir I    hdmi_rx_clk_n
create_bd_port -dir I -from 2 -to 0 hdmi_rx_data_p
create_bd_port -dir I -from 2 -to 0 hdmi_rx_data_n

# HDMI TX Ports
create_bd_port -dir O    hdmi_tx_clk_p
create_bd_port -dir O    hdmi_tx_clk_n
create_bd_port -dir O -from 2 -to 0 hdmi_tx_data_p
create_bd_port -dir O -from 2 -to 0 hdmi_tx_data_n

# LED Port
create_bd_port -dir O -from 3 -to 0 led

# Clock connections
connect_bd_net [get_bd_ports sys_clk]          [get_bd_pins sys_pll/clk_in1]
connect_bd_net [get_bd_pins sys_pll/clk_out1]  [get_bd_pins vtc_0/clk]
connect_bd_net [get_bd_pins sys_pll/clk_out2]  [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins axis_dwidth_0/aclk]

# HDMI RX physical pin connections
connect_bd_net [get_bd_ports hdmi_rx_clk_p]    [get_bd_pins dvi2rgb_0/TMDS_Clk_p]
connect_bd_net [get_bd_ports hdmi_rx_clk_n]    [get_bd_pins dvi2rgb_0/TMDS_Clk_n]
connect_bd_net [get_bd_ports hdmi_rx_data_p]   [get_bd_pins dvi2rgb_0/TMDS_Data_p]
connect_bd_net [get_bd_ports hdmi_rx_data_n]   [get_bd_pins dvi2rgb_0/TMDS_Data_n]

# HDMI TX physical pin connections
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_Clk_p]  [get_bd_ports hdmi_tx_clk_p]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_Clk_n]  [get_bd_ports hdmi_tx_clk_n]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_Data_p] [get_bd_ports hdmi_tx_data_p]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_Data_n] [get_bd_ports hdmi_tx_data_n]

# DVI2RGB -> AXI-Stream Width Converter -> rgb2dvi
connect_bd_intf_net [get_bd_intf_pins dvi2rgb_0/vid_pData] [get_bd_intf_pins axis_dwidth_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_dwidth_0/M_AXIS] [get_bd_intf_pins rgb2dvi_0/vid_io_in]

# Validate and save
puts "\n--- Validating Block Design ---"
validate_bd_design
save_bd_design

# Generate Block Design Wrapper
make_wrapper -files [get_files ${BD_NAME}.bd] -top
add_files -norecurse "$PROJ_DIR/${PROJ_NAME}.srcs/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v"
set_property top ${BD_NAME}_wrapper [current_fileset]

# =============================================================================
# Synthesize, Place, Route and Generate Bitstream
# =============================================================================
puts "\n--- Running Synthesis ---"
synth_design -top ${BD_NAME}_wrapper -part $PART

puts "\n--- Running Power Optimization ---"
opt_design
power_opt_design

puts "\n--- Running Place and Route ---"
place_design
phys_opt_design
route_design

puts "\n--- Generating Bitstream ---"
write_bitstream -force "$PROJ_DIR/tinynpu_2k200j.bit"

puts "============================================================"
puts " TinyNPU2k200J Bitstream Generated!"
puts " Output: $PROJ_DIR/tinynpu_2k200j.bit"
puts "============================================================"
exit
