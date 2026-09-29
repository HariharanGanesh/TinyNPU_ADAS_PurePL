# =============================================================================
# build_and_gen_bitstream.tcl
# Full Non-Project flow: Synthesis, Power Opt, Place, Route, Bitstream
# =============================================================================

set ROOT_DIR    "D:/Final year project"
set SRC_DIR     "$ROOT_DIR/Versions/tinynpu_pynq_system/rtl/src"
set PROJ_DIR    "$ROOT_DIR/vivado_hw_test_proj"
set PROJ_NAME   "tinynpu_hw_test"
set PART        "xc7z020clg400-1"

puts "============================================================"
puts " Building TinyNPU Bitstream for PYNQ-Z2"
puts "============================================================"

# Create project
create_project -force $PROJ_NAME $PROJ_DIR -part $PART

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

# Add Test Wrapper Sources
add_files [glob $SRC_DIR/test_wrappers/*.v]

# Set Top Module
set_property top tinynpu_hw_test_top [current_fileset]

# Constraints (Timing + Physical Pins)
set xdc_file_1 "$PROJ_DIR/timing.xdc"
set fp [open $xdc_file_1 w]
puts $fp "create_clock -period 5.000 -name sys_clk -waveform {0.000 2.500} \[get_ports sys_clk\]"
close $fp

set xdc_file_2 "$ROOT_DIR/Versions/tinynpu_pynq_system/constraints/pynq_z2_pins.xdc"

add_files -fileset constrs_1 [list $xdc_file_1 $xdc_file_2]

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
