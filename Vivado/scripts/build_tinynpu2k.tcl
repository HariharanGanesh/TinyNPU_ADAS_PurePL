# =============================================================================
# build_tinynpu2k.tcl  (v4 — automation-first BD wiring)
# TinyNPU2k (32-bit AXI-Stream, 150MHz) PYNQ-Z2 System Integration Script
#
# KEY FIXES:
#   - Uses apply_bd_automation for all AXI connections (avoids pin name guessing)
#   - Does NOT manually connect_bd_net for DMA clock/reset (let automation handle it)
#   - SmartConnect NUM_SI=2 for separate MM2S and S2MM paths
#   - ip_repo_paths uses [list ...] for Tcl list value
# =============================================================================

set ROOT_DIR "D:/Final year project"
set RTL_DIR  "$ROOT_DIR/rtl"
set IP_DIR   "$ROOT_DIR/TinyNPUIP2k"
set SYS_DIR  "$ROOT_DIR/tinyNPU2k"
set SYS_NAME "tinyNPU2k"
set PART     "xc7z020clg400-1"
set BOARD    "tul.com.tw:pynq-z2:part0:1.0"

puts "============================================================"
puts " TinyNPU2k PYNQ-Z2 System Builder (Sub-10us Latency Edition)"
puts "============================================================"

close_project -quiet

# =============================================================================
# STEP 1: Package TinyNPU2k as IP
# =============================================================================
puts "\n--- STEP 1: Packaging TinyNPU2k IP ---"

set TMP_PROJ_DIR "$ROOT_DIR/tmp_ip_proj"
if {[file exists "$TMP_PROJ_DIR"]} { file delete -force "$TMP_PROJ_DIR" }
create_project tmp_ip_proj "$TMP_PROJ_DIR" -part $PART

# add_files MUST use [list ...] — handles the space in path correctly
add_files [list $RTL_DIR]
update_compile_order -fileset sources_1
set_property top tinynpu_top [current_fileset]

# Package IP
ipx::package_project \
    -root_dir "$IP_DIR" \
    -vendor   user.org \
    -library  user \
    -taxonomy /UserIP \
    -import_files

set_property name             tinynpu_top                              [ipx::current_core]
set_property vendor_display_name "TinyNPU2k"                          [ipx::current_core]
set_property description      "TinyNPU2k 32-bit High Speed AI Accelerator" [ipx::current_core]
set_property version          1.0                                      [ipx::current_core]

ipx::save_core [ipx::current_core]
ipx::check_integrity [ipx::current_core]
puts "IP packaged successfully to: $IP_DIR"
close_project

# =============================================================================
# STEP 2: Create tinyNPU2k System Project
# =============================================================================
puts "\n--- STEP 2: Creating tinyNPU2k System Project ---"

if {[file exists "$SYS_DIR"]} { file delete -force "$SYS_DIR" }
create_project $SYS_NAME "$SYS_DIR" -part $PART

if {[catch {set_property board_part $BOARD [current_project]} err]} {
    puts "WARNING: Board part not found, continuing without board preset."
}

# Register the TinyNPU2k IP repository
set_property ip_repo_paths [list $IP_DIR] [current_project]
update_ip_catalog

# =============================================================================
# STEP 3: Create Block Design (automation-first approach)
# =============================================================================
puts "\n--- STEP 3: Building Block Design ---"

create_bd_design "${SYS_NAME}_bd"

# --- Zynq PS7 with board preset ---
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
    [get_bd_cells ps7]
endgroup

# Configure PS: 150MHz clock, HP0 port, IRQ
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0            {1}   \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {150} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT     {1}   \
    CONFIG.PCW_IRQ_F2P_INTR             {1}   \
] [get_bd_cells ps7]

# --- AXI DMA (32-bit, no scatter-gather) ---
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma
set_property -dict [list \
    CONFIG.c_include_sg               {0}  \
    CONFIG.c_sg_include_stscntrl_strm {0}  \
    CONFIG.c_m_axi_mm2s_data_width    {32} \
    CONFIG.c_m_axis_mm2s_tdata_width  {32} \
    CONFIG.c_s_axis_s2mm_tdata_width  {32} \
    CONFIG.c_mm2s_burst_size          {16} \
    CONFIG.c_s2mm_burst_size          {16} \
    CONFIG.c_include_mm2s             {1}  \
    CONFIG.c_include_s2mm             {1}  \
] [get_bd_cells axi_dma]
endgroup

# --- TinyNPU2k IP ---
startgroup
create_bd_cell -type ip -vlnv user.org:user:tinynpu_top:1.0 npu
endgroup

# =============================================================================
# STEP 4: Wire using apply_bd_automation (Vivado handles pin names correctly)
# =============================================================================
puts "\n--- STEP 4: Auto-connecting Block Design ---"

# GP0 -> DMA AXI-Lite control
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/ps7/M_AXI_GP0} Slave {/axi_dma/S_AXI_LITE} \
              ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}} \
    [get_bd_intf_pins axi_dma/S_AXI_LITE]
endgroup

# GP0 -> NPU AXI-Lite control (reuse the interconnect just created)
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/ps7/M_AXI_GP0} Slave {/npu/s_axi} \
              ddr_seg {Auto} intc_ip {Auto} master_apm {0}} \
    [get_bd_intf_pins npu/s_axi]
endgroup

# DMA MM2S -> HP0 (memory read path)
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/axi_dma/M_AXI_MM2S} Slave {/ps7/S_AXI_HP0} \
              ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}} \
    [get_bd_intf_pins axi_dma/M_AXI_MM2S]
endgroup

# DMA S2MM -> HP0 (memory write path, reuse the HP0 interconnect)
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/axi_dma/M_AXI_S2MM} Slave {/ps7/S_AXI_HP0} \
              ddr_seg {Auto} intc_ip {Auto} master_apm {0}} \
    [get_bd_intf_pins axi_dma/M_AXI_S2MM]
endgroup

# =============================================================================
# STEP 5: Manual connections that automation doesn't cover
# =============================================================================
puts "\n--- STEP 5: Manual stream + clock connections ---"

# AXI-Stream: DMA -> NPU -> DMA
connect_bd_intf_net [get_bd_intf_pins axi_dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins npu/s_axis]
connect_bd_intf_net [get_bd_intf_pins npu/m_axis] \
                    [get_bd_intf_pins axi_dma/S_AXIS_S2MM]

# Connect NPU clock and reset to PS clock/reset
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
               [get_bd_pins npu/clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] \
               [get_bd_pins npu/rst_n]

# Interrupt: DMA mm2s -> PS IRQ_F2P
connect_bd_net [get_bd_pins axi_dma/mm2s_introut] \
               [get_bd_pins ps7/IRQ_F2P]

# =============================================================================
# STEP 6: Assign addresses, validate, wrap
# =============================================================================
puts "\n--- STEP 6: Assign addresses & validate ---"
assign_bd_address

validate_bd_design
puts "Block design validated successfully."

make_wrapper -files [get_files ${SYS_NAME}_bd.bd] -top

# Find the generated wrapper (path differs in Vivado 2024+)
set wrapper_path [lindex [glob -nocomplain \
    "$SYS_DIR/*.gen/sources_1/bd/${SYS_NAME}_bd/hdl/${SYS_NAME}_bd_wrapper.v" \
    "$SYS_DIR/*.srcs/sources_1/bd/${SYS_NAME}_bd/hdl/${SYS_NAME}_bd_wrapper.v"] 0]

if {$wrapper_path eq ""} {
    puts "ERROR: Cannot find generated wrapper. Aborting."
} else {
    puts "Wrapper: $wrapper_path"
    add_files -norecurse [list $wrapper_path]
    set_property top ${SYS_NAME}_bd_wrapper [current_fileset]
    update_compile_order -fileset sources_1

    # =============================================================================
    # STEP 7: Synthesize, Implement, Generate Bitstream
    # =============================================================================
    puts "\n--- STEP 7: Launching Synthesis -> Implementation -> Bitstream ---"
    puts "    Expected time: 15-25 minutes."
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1

    set impl_status [get_property STATUS [get_runs impl_1]]
    puts "\n============================================================"
    if {[string match "*Complete*" $impl_status]} {
        puts " TinyNPU2k BUILD COMPLETE!"
        puts " Status: $impl_status"
        set bit_files [glob -nocomplain "$SYS_DIR/*.runs/impl_1/*.bit"]
        foreach f $bit_files { puts " Bitstream: $f" }
    } else {
        puts " BUILD STATUS: $impl_status"
        puts " Check: $SYS_DIR/$SYS_NAME.runs/impl_1/runme.log"
    }
    puts "============================================================"
}
