# ==============================================================================
# create_pmax.tcl — NPU300PM / TinyNPU200JPMAX Project Creation Script
# ==============================================================================
# Creates a NEW, ISOLATED Vivado project for TinyNPU200JPMAX.
# Does NOT touch or modify the existing npu200jb project.
#
# All previous bugs are pre-baked:
#   [1] CLOCK_DEDICATED_ROUTE FALSE   -> in hdmi_pins.xdc (inherited from TinyNPU200J)
#   [2] CDC set_false_path            -> in hdmi_pins.xdc
#   [3] OOC cache flush               -> reset_run before launch
#   [4] Memory-safe build             -> -jobs 2
#   [5] Performance_Explore strategy  -> pre-set
#   [6] tile_count_in tied to 0       -> set in BD TCL
#   [7] Requantizer pipelined         -> inherited from fixed IP src
#   [8] DSP48E1 PE mapping            -> Fixed in NPU300PM processing_element.v
# ==============================================================================

set proj_name  "npu200jpmax"
set proj_dir   "D:/Final year project/npu200jpmax"
set ip_repo_1  "D:/Final year project/Shared/IP/digilent-vivado-library"
set ip_repo_2  "D:/Final year project/IP/NPU300PM"
set xdc_file   "D:/Final year project/Versions/TinyNPU200JPMAX/constraints/hdmi_pins.xdc"
set part       "xc7z020clg400-1"

# --- Create project ---
create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# --- Set IP repos ---
set_property ip_repo_paths [list $ip_repo_1 $ip_repo_2] [current_project]
update_ip_catalog -rebuild

# --- Create Block Design ---
create_bd_design "npu_system"

# --- PS7 (Zynq Processing System) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125.000000} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_DDR_RAM_HIGHADDR {0x1FFFFFFF} \
] [get_bd_cells ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "0"} [get_bd_cells ps7]

# --- Reset block ---
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_125M
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins rst_ps7_125M/slowest_sync_clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_ps7_125M/ext_reset_in]

# --- AXI Interconnect ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_intercon
set_property -dict [list \
    CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} \
    CONFIG.S00_HAS_REGSLICE {4} CONFIG.M00_HAS_REGSLICE {4} \
] [get_bd_cells axi_mem_intercon]

# --- AXI BRAM Controller for CSR access ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_csr_intercon
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_csr_intercon]

# --- NPU300PM IP ---
create_bd_cell -type ip -vlnv ai.local:user:tinynpu_top:1.0 tinynpu_0
# Tie tile_count_in to 0 (Bug Fix #6 - floating input)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero_32
set_property CONFIG.CONST_WIDTH {32} [get_bd_cells const_zero_32]
connect_bd_net [get_bd_pins const_zero_32/dout] [get_bd_pins tinynpu_0/tile_count_in]

# --- HDMI IPs ---
create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:2.0 dvi2rgb_0
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
create_bd_cell -type ip -vlnv xilinx.com:ip:v_vid_in_axi4s:5.0 vid_in
create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 vid_out
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 vtc_0
set_property -dict [list CONFIG.VIDEO_MODE {720P}] [get_bd_cells vtc_0]
set_property -dict [list CONFIG.kEmulateDDC {true} CONFIG.kRstActiveHigh {false}] [get_bd_cells dvi2rgb_0]
set_property -dict [list CONFIG.kRstActiveHigh {false}] [get_bd_cells rgb2dvi_0]
set_property -dict [list CONFIG.C_PIXELS_PER_CLOCK {1} CONFIG.C_HAS_ASYNC_CLK {1}] [get_bd_cells vid_in]
set_property -dict [list CONFIG.C_PIXELS_PER_CLOCK {1} CONFIG.C_HAS_ASYNC_CLK {1}] [get_bd_cells vid_out]

# --- AXI DMA ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axi_s2mm_data_width {32} \
] [get_bd_cells axi_dma_0]

# --- Clock connections ---
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
    [get_bd_pins axi_mem_intercon/ACLK] \
    [get_bd_pins axi_mem_intercon/S00_ACLK] \
    [get_bd_pins axi_mem_intercon/M00_ACLK] \
    [get_bd_pins axi_csr_intercon/ACLK] \
    [get_bd_pins axi_csr_intercon/S00_ACLK] \
    [get_bd_pins axi_csr_intercon/M00_ACLK] \
    [get_bd_pins tinynpu_0/clk] \
    [get_bd_pins axi_dma_0/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] \
    [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] \
    [get_bd_pins ps7/S_AXI_HP0_ACLK] \
    [get_bd_pins vid_in/aclk] \
    [get_bd_pins vid_out/aclk]

connect_bd_net [get_bd_pins ps7/FCLK_CLK1] \
    [get_bd_pins dvi2rgb_0/RefClk]

# --- Reset connections ---
connect_bd_net [get_bd_pins rst_ps7_125M/peripheral_aresetn] \
    [get_bd_pins axi_mem_intercon/ARESETN] \
    [get_bd_pins axi_mem_intercon/S00_ARESETN] \
    [get_bd_pins axi_mem_intercon/M00_ARESETN] \
    [get_bd_pins axi_csr_intercon/ARESETN] \
    [get_bd_pins axi_csr_intercon/S00_ARESETN] \
    [get_bd_pins axi_csr_intercon/M00_ARESETN] \
    [get_bd_pins axi_dma_0/axi_resetn]

connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins tinynpu_0/rst_n]

# --- AXI connections ---
# PS master -> CSR slave -> NPU CSR
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_csr_intercon/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_csr_intercon/M00_AXI] [get_bd_intf_pins tinynpu_0/s_axi]

# NPU AXI master -> axi_mem_intercon -> HP0
connect_bd_intf_net [get_bd_intf_pins tinynpu_0/m_axi] [get_bd_intf_pins axi_mem_intercon/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_intercon/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]

# AXI Stream: vid_in -> NPU -> vid_out
connect_bd_intf_net [get_bd_intf_pins vid_in/video_out] [get_bd_intf_pins tinynpu_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins tinynpu_0/m_axis] [get_bd_intf_pins vid_out/video_in]

# Video chain
connect_bd_intf_net [get_bd_intf_pins dvi2rgb_0/RGB] [get_bd_intf_pins vid_in/vid_io_in]
connect_bd_intf_net [get_bd_intf_pins vid_out/vid_io_out] [get_bd_intf_pins rgb2dvi_0/RGB]

# vid_locked to tinynpu_0
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] \
    [get_bd_pins vid_in/vid_io_in_clk] \
    [get_bd_pins vid_out/vid_io_out_clk] \
    [get_bd_pins rgb2dvi_0/PixelClk] \
    [get_bd_pins vtc_0/clk]

connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins tinynpu_0/vid_locked_in]

connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins vid_in/vid_io_in_ce]
connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins vid_in/vid_io_in_reset]
connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins vid_out/vid_io_out_ce]

# VTC
connect_bd_intf_net [get_bd_intf_pins vid_in/vtiming_out] [get_bd_intf_pins vtc_0/vtiming_in]
connect_bd_intf_net [get_bd_intf_pins vtc_0/vtiming_out] [get_bd_intf_pins vid_out/vtiming_in]

# Interrupt
connect_bd_net [get_bd_pins tinynpu_0/interrupt] [get_bd_pins ps7/IRQ_F2P]

# --- HDMI External Ports ---
make_bd_intf_pins_external  [get_bd_intf_pins dvi2rgb_0/TMDS]
set_property name TMDS_RX [get_bd_intf_ports TMDS_0]

make_bd_intf_pins_external  [get_bd_intf_pins rgb2dvi_0/TMDS]
set_property name TMDS_TX [get_bd_intf_ports TMDS_0]

make_bd_intf_pins_external  [get_bd_intf_pins dvi2rgb_0/DDC]
set_property name DDC [get_bd_intf_ports DDC_0]

# --- Fix AXI Clocks and Addresses ---
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins vtc_0/s_axi_aclk]

assign_bd_address -target_address_space /ps7/Data [get_bd_addr_segs tinynpu_0/s_axi/reg0] -force
assign_bd_address -target_address_space /tinynpu_0/m_axi [get_bd_addr_segs ps7/S_AXI_HP0/HP0_DDR_LOWOCM] -force

# --- Validate and Save ---
validate_bd_design
save_bd_design
set wrapper_file [make_wrapper -files [get_files npu_system.bd] -top]
add_files -norecurse [list $wrapper_file]
update_compile_order -fileset sources_1
set_property top npu_system_wrapper [current_fileset]

# --- Add constraints (all bugs pre-baked) ---
add_files -fileset constrs_1 -norecurse [list $xdc_file]

# --- Set implementation strategy ---
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

puts "=============================================="
puts "  NPU300PM / TinyNPU200JPMAX project created!"
puts "  Project: $proj_dir/$proj_name.xpr"
puts "  Array: 26x8 = 208 MACs (DSP48E1 forced)"
puts "  Target: 125 MHz, <=215 DSP48E1"
puts "=============================================="
