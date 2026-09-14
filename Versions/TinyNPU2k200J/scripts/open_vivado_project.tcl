# =============================================================================
# open_vivado_project.tcl — TinyNPU v3.0 Vivado GUI Project Creator
# Run this once to create the Vivado project. After that, open the .xpr file.
#
# Usage (from Vivado TCL Console or batch):
#   vivado -mode tcl -source open_vivado_project.tcl
#
# Or double-click run_vivado.bat to launch with GUI.
# =============================================================================

set ROOT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR "$ROOT_DIR/vivado_project"
set PROJ_NAME "tinynpu_v3"
set PART "xc7z020clg400-1"

# Remove old project if exists
if {[file exists "$PROJ_DIR/$PROJ_NAME.xpr"]} {
    puts "INFO: Existing project found. Opening it..."
    open_project "$PROJ_DIR/$PROJ_NAME.xpr"
    start_gui
    return
}

puts "INFO: Creating new Vivado project: $PROJ_NAME"
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# -----------------------------------------------
# Set project properties
# -----------------------------------------------
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
# NOTE: To set PYNQ-Z2 board, install board files and run:
# set_property BOARD_PART tul.com.tw:pynq-z2:part0:1.0 [current_project]

# -----------------------------------------------
# Add RTL sources from 01_RTL
# -----------------------------------------------
add_files -norecurse [glob -nocomplain \
    "$ROOT_DIR/01_RTL/core/*.v"          \
    "$ROOT_DIR/01_RTL/activation/*.v"    \
    "$ROOT_DIR/01_RTL/axi/*.v"           \
    "$ROOT_DIR/01_RTL/buffers/*.v"       \
    "$ROOT_DIR/01_RTL/clocking/*.v"      \
    "$ROOT_DIR/01_RTL/control/*.v"       \
    "$ROOT_DIR/01_RTL/dma/*.v"           \
    "$ROOT_DIR/01_RTL/dw_engine/*.v"     \
    "$ROOT_DIR/01_RTL/pe/*.v"            \
    "$ROOT_DIR/01_RTL/pooling/*.v"       \
    "$ROOT_DIR/01_RTL/quantization/*.v"  \
    "$ROOT_DIR/01_RTL/systolic_array/*.v" \
    "$ROOT_DIR/01_RTL/top/*.v"           \
    "$ROOT_DIR/01_RTL/wrappers/fpga/*.v" \
]

# -----------------------------------------------
# Add Verification / Simulation sources
# -----------------------------------------------
# Monitor and scoreboard (synthesizable, add to sim fileset)
add_files -fileset sim_1 -norecurse [glob -nocomplain \
    "$ROOT_DIR/02_Verification/monitor/*.v"    \
    "$ROOT_DIR/02_Verification/scoreboard/*.v" \
    "$ROOT_DIR/02_Verification/assertions/*.sv" \
    "$ROOT_DIR/02_Verification/hw_verif/*.v"   \
    "$ROOT_DIR/02_Verification/tb/*.sv"        \
]

# -----------------------------------------------
# Add hex/stimulus files to simulation fileset
# -----------------------------------------------
add_files -fileset sim_1 -norecurse [glob -nocomplain \
    "$ROOT_DIR/02_Verification/vectors/*.hex"  \
    "$ROOT_DIR/02_Verification/vectors/*.txt"  \
]

# -----------------------------------------------
# Add XDC Constraints
# -----------------------------------------------
add_files -fileset constrs_1 -norecurse \
    [list "$ROOT_DIR/04_Synthesis/constraints/tinynpu.xdc"]

# -----------------------------------------------
# Set top modules
# -----------------------------------------------
set_property top tinynpu_top [current_fileset]
set_property top tinynpu_system_tb [get_filesets sim_1]

# -----------------------------------------------
# Simulation settings for xsim
# -----------------------------------------------
set_property verilog_define "BEHAVIORAL_CG" [get_filesets sim_1]
set_property xsim.simulate.runtime {all} [get_filesets sim_1]
set_property xsim.simulate.log_all_signals true [get_filesets sim_1]

# -----------------------------------------------
# Add IP Repository for TinyNPU packaged IP
# -----------------------------------------------
set_property ip_repo_paths [list "$ROOT_DIR/05_IP"] [current_project]
update_ip_catalog

# -----------------------------------------------
# Save project
# -----------------------------------------------
# Properties auto-save, but we can force it:
# save_project is implicit when closing, but GUI keeps it open.

puts ""
puts "============================================================"
puts "  TinyNPU v3.0 Vivado Project Created!"
puts "  Project: $PROJ_DIR/$PROJ_NAME.xpr"
puts ""
puts "  HOW TO RUN SIMULATION:"
puts "    1. Flow Navigator -> Simulation -> Run Simulation"
puts "       -> Run Behavioral Simulation"
puts "    2. In waveform viewer, add signals and press Run All"
puts "    3. Check TCL console for PASS/FAIL report"
puts ""
puts "  HOW TO SYNTHESIZE:"
puts "    1. Flow Navigator -> Synthesis -> Run Synthesis"
puts "    2. Flow Navigator -> Implementation -> Run Implementation"
puts "============================================================"

# Launch GUI
start_gui
