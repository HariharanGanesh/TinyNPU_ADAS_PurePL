# =============================================================================
# build_and_gen_bitstream.tcl
# Full Non-Project flow: Synthesis, Power Opt, Place, Route, Bitstream
# =============================================================================

set ROOT_DIR    "D:/Final year project"
set SRC_DIR     "$ROOT_DIR/Versions/TinyNPU2k200/rtl/src"
set PROJ_DIR    "$ROOT_DIR/vivado_hw_test_proj"
set PROJ_NAME   "tinynpu_hw_test"
set PART        "xc7z020clg400-1"

puts "============================================================"
puts " Building TinyNPU Bitstream for PYNQ-Z2"
puts "============================================================"

# Create project
create_project -force $PROJ_NAME $PROJ_DIR -part $PART

# Generate Clocking Wizard IP (195 MHz)
puts "\n--- Generating Clocking Wizard IP ---"
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name sys_pll
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {125.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {195.000} \
  CONFIG.CLKOUT2_USED       {true}   \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.USE_RESET {false} \
] [get_ips sys_pll]
generate_target all [get_ips sys_pll]
synth_ip [get_ips sys_pll]

# Add Core RTL Sources
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

# Add HDMI IP repository (Digilent)
set_property ip_repo_paths [list \
    {D:/Final year project/Shared/IP/ip_repo} \
    {D:/Final year project/Shared/IP/digilent-vivado-library/ip} \
] [current_project]
update_ip_catalog -rebuild

# Add OSD and wrapper sources
add_files [glob $SRC_DIR/osd/*.v]
add_files [glob $SRC_DIR/test_wrappers/tinynpu_hdmi_top.v]

# Set Top Module
set_property top tinynpu_hdmi_top [current_fileset]

# Constraints (HDMI Physical Pins)
set xdc_file "$ROOT_DIR/Versions/TinyNPU2k200J/constraints/hdmi_pins.xdc"
add_files -fileset constrs_1 [list $xdc_file]

# Synthesis
puts "\n--- Running Synthesis ---"
synth_design -top tinynpu_hw_test_top -part $PART -directive Default

# Power Optimization
puts "\n--- Running Power Optimization ---"
opt_design
power_opt_design

# Placement & Routing
puts "\n--- Running Place & Route ---"
place_design
phys_opt_design
route_design

# Generate Bitstream
puts "\n--- Generating Bitstream ---"
write_bitstream -force "$PROJ_DIR/tinynpu_hw_test.bit"

puts "============================================================"
puts " Bitstream Generated Successfully!"
puts " Output: $PROJ_DIR/tinynpu_hw_test.bit"
puts "============================================================"
exit
