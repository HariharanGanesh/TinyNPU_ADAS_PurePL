# =============================================================================
# synth_impl.tcl — TinyNPU v2.0 Synthesis + Implementation Script
# Target:  PYNQ-Z2  (Xilinx Zynq-7020, XC7Z020CLG400-1)
# Tool:    Vivado 2025.1
#
# Usage:
#   vivado -mode batch -source synth_impl.tcl
#
# Outputs (./synth_out/):
#   utilization_synth.rpt  — Post-synthesis utilization
#   utilization_impl.rpt   — Post-implementation utilization (accurate)
#   timing_summary.rpt     — WNS / TNS / critical paths (real numbers)
#   power_estimate.rpt     — Power with clock constraints applied
#   tinynpu_top_routed.dcp — Routed checkpoint for bitstream generation
# =============================================================================

set PART     "xc7z020clg400-1"
set TOP      "tinynpu_top"
set OUT_DIR  "04_Synthesis/reports"

file mkdir $OUT_DIR
file mkdir "04_Synthesis/checkpoints"

# -----------------------------------------------
# Create in-memory project
# -----------------------------------------------
create_project -in_memory -part $PART

# -----------------------------------------------
# Read all RTL source files
# -----------------------------------------------
set rtl_files [glob -nocomplain \
    "01_RTL/core/*.v"          \
    "01_RTL/activation/*.v"    \
    "01_RTL/axi/*.v"           \
    "01_RTL/buffers/*.v"       \
    "01_RTL/clocking/*.v"      \
    "01_RTL/control/*.v"       \
    "01_RTL/dma/*.v"           \
    "01_RTL/dw_engine/*.v"     \
    "01_RTL/pe/*.v"            \
    "01_RTL/pooling/*.v"       \
    "01_RTL/quantization/*.v"  \
    "01_RTL/systolic_array/*.v" \
    "01_RTL/top/*.v"           \
    "01_RTL/wrappers/fpga/*.v" \
]
read_verilog -sv $rtl_files
puts "INFO: Read [llength $rtl_files] RTL files."

# -----------------------------------------------
# Read XDC Constraints
# -----------------------------------------------
read_xdc "04_Synthesis/constraints/tinynpu.xdc"
puts "INFO: Loaded timing constraints from tinynpu.xdc"

# -----------------------------------------------
# Set top module
# -----------------------------------------------
set_property top $TOP [current_fileset]

# -----------------------------------------------
# STEP 1: Synthesis — Out-of-Context (OOC) mode
#
# ENGINEERING RATIONALE:
# TinyNPU is an AXI IP core that connects to the Zynq PS AXI Interconnect
# inside a Block Design. Its ports (m_axi_*, s_axi_*, s_axis_*, m_axis_*)
# are NOT physical package pins — they are internal chip wires.
#
# OOC mode instructs Vivado:
#  1. Do NOT infer IBUF/OBUF on ports (they are internal connections)
#  2. Do NOT require IOB LOC constraints
#  3. Treat the design as a netlist block for timing closure
#
# This is the correct flow for any Zynq PS IP (NVDLA, TensorRT IP, etc.)
# -----------------------------------------------
puts "INFO: Starting OOC synthesis..."
synth_design \
    -top    $TOP  \
    -part   $PART \
    -mode   out_of_context \
    -flatten_hierarchy rebuilt \
    -directive AreaOptimized_high

report_utilization -hierarchical -file $OUT_DIR/utilization_synth.rpt
puts "INFO: Post-synthesis utilization written."

# -----------------------------------------------
# STEP 2: Optimise Netlist
# -----------------------------------------------
puts "INFO: Optimising netlist..."
opt_design

# -----------------------------------------------
# STEP 3: Place
# -----------------------------------------------
puts "INFO: Placing design..."
place_design -directive AltSpreadLogic_high

# -----------------------------------------------
# STEP 4: Route
# -----------------------------------------------
puts "INFO: Routing design..."
route_design -directive AggressiveExplore

# -----------------------------------------------
# STEP 5: Reports (post-implementation — real numbers)
# -----------------------------------------------
puts "INFO: Generating post-implementation reports..."

report_utilization \
    -hierarchical \
    -file $OUT_DIR/utilization_impl.rpt

report_timing_summary \
    -max_paths 20 \
    -file $OUT_DIR/timing_summary.rpt

report_clock_interaction \
    -file $OUT_DIR/clock_interaction.rpt

report_power \
    -file $OUT_DIR/power_estimate.rpt

report_route_status \
    -file $OUT_DIR/route_status.rpt

# -----------------------------------------------
# STEP 6: Write routed checkpoint
# -----------------------------------------------
write_checkpoint -force "04_Synthesis/checkpoints/tinynpu_top_routed.dcp"
puts "INFO: Routed checkpoint written to 04_Synthesis/checkpoints/tinynpu_top_routed.dcp"

puts ""
puts "================================================================"
puts "  TinyNPU Synthesis + Implementation Complete"
puts "  Part:    $PART  (PYNQ-Z2 Zynq-7020)"
puts "  Clock:   100 MHz (10 ns period)"
puts "  Reports: $OUT_DIR/"
puts "================================================================"
