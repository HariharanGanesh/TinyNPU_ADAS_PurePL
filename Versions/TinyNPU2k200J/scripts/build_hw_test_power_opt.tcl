# =============================================================================
# build_hw_test_power_opt.tcl
# Builds the Option A (Pure Hardware) test with aggressive Power Optimizations.
# =============================================================================

set ROOT_DIR    "D:/Final year project"
set SRC_DIR     "$ROOT_DIR/Versions/tinynpu_pynq_system/rtl/src"
set PROJ_DIR    "$ROOT_DIR/vivado_hw_test_proj"
set PROJ_NAME   "tinynpu_hw_test"
set PART        "xc7z020clg400-1"

puts "============================================================"
puts " Building TinyNPU Hardware Test (with Power Opt)"
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

# Constraints (we would add an XDC for PYNQ-Z2 here, but for now we just do out-of-context or synthesize without pins to get timing/power)
# We will create a dummy clock constraint to ensure 200 MHz timing is checked.
set xdc_file "$PROJ_DIR/timing.xdc"
set fp [open $xdc_file w]
puts $fp "create_clock -period 5.000 -name sys_clk -waveform {0.000 2.500} \[get_ports sys_clk\]"
close $fp
add_files -fileset constrs_1 [list $xdc_file]

# Synthesis
puts "\n--- Running Synthesis ---"
synth_design -top tinynpu_hw_test_top -part $PART -directive Default

# Power Optimization (The Core of the Power Optimization Plan)
puts "\n--- Running Power Optimization (power_opt_design) ---"
opt_design
power_opt_design

# Placement & Routing
puts "\n--- Running Place & Route ---"
place_design
phys_opt_design
route_design

# Reports
puts "\n--- Generating Reports ---"
report_timing_summary -file "$PROJ_DIR/post_route_timing.rpt"
report_power -file "$PROJ_DIR/post_route_power.rpt"
report_utilization -file "$PROJ_DIR/post_route_util.rpt"

puts "============================================================"
puts " Build Complete! Check $PROJ_DIR for reports."
puts "============================================================"
exit
