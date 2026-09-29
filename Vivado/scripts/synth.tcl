# =============================================================================
# synth.tcl — TinyNPU v2.0 Out-of-Context Synthesis Script
# Target:  PYNQ-Z2  (Xilinx Zynq-7020, XC7Z020CLG400-1)
# Tool:    Vivado 2025.1
#
# Usage (from project root):
#   vivado -mode batch -source synth.tcl
#
# Outputs (written to ./synth_out/):
#   utilization.rpt   — LUT / BRAM / DSP / FF breakdown
#   timing_summary.rpt— Critical path / WNS / TNS
#   tinynpu_top.dcp   — Design checkpoint for further P&R
# =============================================================================

set PART     "xc7z020clg400-1"
set TOP      "tinynpu_top"
set OUT_DIR  "./synth_out"

file mkdir $OUT_DIR

# -----------------------------------------------
# Create in-memory project targeting Zynq-7020
# -----------------------------------------------
create_project -in_memory -part $PART

# -----------------------------------------------
# Read all RTL source files
# -----------------------------------------------
set rtl_files [glob -nocomplain \
    rtl/activation/*.v   \
    rtl/axi/*.v          \
    rtl/buffers/*.v      \
    rtl/clocking/*.v     \
    rtl/control/*.v      \
    rtl/dma/*.v          \
    rtl/dw_engine/*.v    \
    rtl/pe/*.v           \
    rtl/pooling/*.v      \
    rtl/quantization/*.v \
    rtl/systolic_array/*.v \
    rtl/top/*.v          \
]

read_verilog -sv $rtl_files
puts "INFO: Read [llength $rtl_files] RTL files."

# -----------------------------------------------
# Set top module & synth strategy
# -----------------------------------------------
set_property top $TOP [current_fileset]

# -----------------------------------------------
# Run Synthesis
# Out-of-context (OOC) to analyse PL fabric only
# without Zynq PS wrappers
# -----------------------------------------------
puts "INFO: Starting synthesis for $TOP on $PART ..."
synth_design \
    -top    $TOP  \
    -part   $PART \
    -flatten_hierarchy rebuilt \
    -directive AreaOptimized_high

# -----------------------------------------------
# Generate Reports
# -----------------------------------------------
puts "INFO: Generating utilization report..."
report_utilization \
    -hierarchical \
    -file $OUT_DIR/utilization.rpt

puts "INFO: Generating timing summary..."
report_timing_summary \
    -max_paths 10 \
    -file $OUT_DIR/timing_summary.rpt

puts "INFO: Generating clock interaction report..."
report_clock_interaction \
    -file $OUT_DIR/clock_interaction.rpt

puts "INFO: Generating power estimate..."
report_power \
    -file $OUT_DIR/power_estimate.rpt

# -----------------------------------------------
# Write DCP checkpoint
# -----------------------------------------------
puts "INFO: Writing design checkpoint..."
write_checkpoint -force $OUT_DIR/tinynpu_top.dcp

puts ""
puts "================================================================"
puts "  TinyNPU Synthesis Complete"
puts "  Part:    $PART  (PYNQ-Z2 Zynq-7020)"
puts "  Reports: $OUT_DIR/"
puts "================================================================"
