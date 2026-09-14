# =============================================================================
# build_pynq_system.tcl
# TinyNPU PYNQ-Z2 System Integration Script
#
# STEP 1: Packages tinynpu_top as a Vivado IP from the current OOC project
# STEP 2: Creates a new full-system project with Zynq PS + AXI DMA + TinyNPU
# STEP 3: Runs implementation and generates the bitstream
#
# Run from Vivado Tcl Console:
#   source {d:/Final year project/build_pynq_system.tcl}
# =============================================================================

set ROOT_DIR    "D:/Final year project"
set IP_DIR      "$ROOT_DIR/tinynpu_ip"
set SYS_DIR     "$ROOT_DIR/vivado_system"
set SYS_NAME    "tinynpu_pynq_system"
set PART        "xc7z020clg400-1"
set BOARD       "tul.com.tw:pynq-z2:part0:1.0"

puts "============================================================"
puts " TinyNPU PYNQ-Z2 System Builder"
puts "============================================================"

# =============================================================================
# STEP 1: Package TinyNPU as IP
# =============================================================================
puts "\n--- STEP 1: Packaging TinyNPU IP ---"

# Make sure we are in the right project
open_project "$ROOT_DIR/vivado_project/tinynpu_v3.xpr"

# Package the project as IP
ipx::package_project \
    -root_dir $IP_DIR \
    -vendor   user.org \
    -library  user \
    -taxonomy /UserIP \
    -import_files

# Set IP core metadata
set_property name            tinynpu_top          [ipx::current_core]
set_property vendor_display_name "TinyNPU Project" [ipx::current_core]
set_property description    "TinyNPU INT8 Systolic Array AI Accelerator for YOLOv8n" [ipx::current_core]
set_property version        1.0                  [ipx::current_core]

# Infer AXI interfaces from port names automatically
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0  [ipx::current_core]

# Save and check the IP
ipx::save_core [ipx::current_core]
ipx::check_integrity [ipx::current_core]

puts "IP packaged successfully to: $IP_DIR"

# =============================================================================
# STEP 2: Create the PYNQ-Z2 System Project
# =============================================================================
puts "\n--- STEP 2: Creating PYNQ-Z2 System Project ---"

# Close the NPU project and create a fresh system project
close_project

# Remove old system project if it exists
if {[file exists "$SYS_DIR"]} {
    file delete -force $SYS_DIR
}

create_project $SYS_NAME $SYS_DIR -part $PART

# Set board (try PYNQ-Z2, fall back gracefully if not installed)
if {[catch {set_property board_part $BOARD [current_project]} err]} {
    puts "WARNING: Board part not found, continuing without board preset."
}

# Add our custom TinyNPU IP repo
set_property  ip_repo_paths $IP_DIR [current_project]
update_ip_catalog

# =============================================================================
# STEP 3: Create the Block Design
# =============================================================================
puts "\n--- STEP 3: Building Block Design ---"

create_bd_design "tinynpu_system_bd"
open_bd_design  [get_files tinynpu_system_bd.bd]

# --- Add Zynq PS7 ---
set zynq [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $zynq

# Configure Zynq PS:
# - Enable HP0 slave port for DMA high-bandwidth access
# - Enable GP0 master port for NPU register control
# - Set FCLK_CLK0 to 100 MHz
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0        {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR         {1} \
] $zynq

# --- Add AXI Interconnect (2 masters: GP0 → NPU CSR + DMA ctrl) ---
set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $axi_ic

# --- Add AXI DMA (for streaming data to/from TinyNPU) ---
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
set_property -dict [list \
    CONFIG.c_include_sg          {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axis_mm2s_tdata_width {8} \
    CONFIG.c_mm2s_burst_size     {16} \
    CONFIG.c_s2mm_burst_size     {16} \
    CONFIG.c_include_mm2s        {1} \
    CONFIG.c_include_s2mm        {1} \
] $dma

# --- Add TinyNPU IP ---
set npu [create_bd_cell -type ip -vlnv user.org:user:tinynpu_top:1.0 npu]

# --- Add AXI SmartConnect for HP0 (DMA → DDR) ---
set hp0_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 hp0_ic]
set_property -dict [list CONFIG.NUM_SI {1}] $hp0_ic

# =============================================================================
# STEP 4: Wire the Block Design
# =============================================================================
puts "\n--- STEP 4: Connecting Block Design ---"

# Clock and Reset
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
    [get_bd_pins ps7/M_AXI_GP0_ACLK] \
    [get_bd_pins ps7/S_AXI_HP0_ACLK] \
    [get_bd_pins axi_ic/ACLK] \
    [get_bd_pins axi_ic/S00_ACLK] \
    [get_bd_pins axi_ic/M00_ACLK] \
    [get_bd_pins axi_ic/M01_ACLK] \
    [get_bd_pins dma/s_axi_lite_aclk] \
    [get_bd_pins dma/m_axi_mm2s_aclk] \
    [get_bd_pins dma/m_axi_s2mm_aclk] \
    [get_bd_pins hp0_ic/aclk] \
    [get_bd_pins npu/clk]

connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] \
    [get_bd_pins axi_ic/ARESETN] \
    [get_bd_pins axi_ic/S00_ARESETN] \
    [get_bd_pins axi_ic/M00_ARESETN] \
    [get_bd_pins axi_ic/M01_ARESETN] \
    [get_bd_pins dma/axi_resetn] \
    [get_bd_pins hp0_ic/aresetn] \
    [get_bd_pins npu/rst_n]

# GP0 → AXI Interconnect → DMA Ctrl + NPU CSR
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0]    [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI]   [get_bd_intf_pins dma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M01_AXI]   [get_bd_intf_pins npu/s_axi]

# DMA Stream → NPU → DMA Stream
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S]  [get_bd_intf_pins npu/s_axis]
connect_bd_intf_net [get_bd_intf_pins npu/m_axis]       [get_bd_intf_pins dma/S_AXIS_S2MM]

# DMA → HP0 → DDR (high bandwidth memory access)
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S]  [get_bd_intf_pins hp0_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM]  [get_bd_intf_pins hp0_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_ic/M00_AXI]  [get_bd_intf_pins ps7/S_AXI_HP0]

# DMA interrupt to PS
connect_bd_net [get_bd_pins dma/mm2s_introut] [get_bd_pins ps7/IRQ_F2P]

# =============================================================================
# STEP 5: Assign Addresses
# =============================================================================
puts "\n--- STEP 5: Assigning Addresses ---"
assign_bd_address

# =============================================================================
# STEP 6: Validate, wrap, and add to project
# =============================================================================
puts "\n--- STEP 6: Validating Block Design ---"
validate_bd_design

make_wrapper -files [get_files tinynpu_system_bd.bd] -top
add_files -norecurse "$SYS_DIR/$SYS_NAME.srcs/sources_1/bd/tinynpu_system_bd/hdl/tinynpu_system_bd_wrapper.v"
set_property top tinynpu_system_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# =============================================================================
# STEP 7: Generate Bitstream
# =============================================================================
puts "\n--- STEP 7: Launching Synthesis → Implementation → Bitstream ---"
puts "    This will take 10-20 minutes. Please wait..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "\n============================================================"
puts " BUILD COMPLETE!"
puts " Bitstream: $SYS_DIR/$SYS_NAME.runs/impl_1/tinynpu_system_bd_wrapper.bit"
puts " Hardware:  Export from Vivado: File → Export → Export Hardware"
puts "============================================================"
