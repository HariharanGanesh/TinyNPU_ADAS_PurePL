# =============================================================================
# rebuild_all_clean.tcl
# TinyNPU2k200J - Clean automated build from scratch to bitstream
# =============================================================================

set ROOT_DIR   "D:/Final year project"
set SRC_DIR    "$ROOT_DIR/Versions/TinyNPU2k200J/rtl/src"
set PROJ_DIR   "$ROOT_DIR/vivado_2k200j_proj"
set PROJ_NAME  "tinynpu_2k200j"
set PART       "xc7z020clg400-1"

puts "============================================================"
puts " TinyNPU2k200J Clean Build Script"
puts "============================================================"

# Create clean project (force overwrites old corrupt one)
create_project -force $PROJ_NAME $PROJ_DIR -part $PART

# Add Digilent IP Repository
set_property ip_repo_paths [list \
    "$ROOT_DIR/Shared/IP/ip_repo" \
    "$ROOT_DIR/Shared/IP/digilent-vivado-library/ip" \
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
add_files -fileset constrs_1 [list "$ROOT_DIR/Versions/TinyNPU2k200J/constraints/hdmi_pins.xdc"]

# Set Top Module
set_property top tinynpu_hdmi_top [current_fileset]

puts "\n--- Generating IP Cores ---"

# 1. Generate Clocking Wizard (sys_pll)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name sys_pll
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {195.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false} \
] [get_ips sys_pll]
generate_target all [get_ips sys_pll]

# 2. Generate DVI2RGB (pynq_dvi_rx)
create_ip -name dvi2rgb -vendor digilentinc.com -library ip -version 2.0 -module_name pynq_dvi_rx
set_property -dict [list \
    CONFIG.kEmulateDDC   {false} \
    CONFIG.kAddBUFG      {true}  \
    CONFIG.kRstActiveHigh {true} \
] [get_ips pynq_dvi_rx]
generate_target all [get_ips pynq_dvi_rx]
# Force OOC re-synthesis to pick up KEEP attribute fix on ResetBridge
synth_ip [get_ips pynq_dvi_rx]

# 3. Generate RGB2DVI (pynq_dvi_tx)
create_ip -name rgb2dvi -vendor digilentinc.com -library ip -version 1.4 -module_name pynq_dvi_tx
set_property -dict [list \
    CONFIG.kGenerateSerialClk {true} \
    CONFIG.kClkPrimitive      {MMCM} \
    CONFIG.kClkRange          {2}    \
] [get_ips pynq_dvi_tx]
generate_target all [get_ips pynq_dvi_tx]
# Force synthesis of IP to apply MMCM configuration
synth_ip [get_ips pynq_dvi_tx]

update_compile_order -fileset sources_1

puts "\n--- Running Synthesis ---"
launch_runs synth_1 -jobs 8
wait_on_run synth_1

puts "\n--- Running Implementation & Bitstream ---"
# Workaround: downgrade DRC NDRV-1 to warning for dvi2rgb v2.0 + Vivado 2025.1 OOC trimming bug
set_property SEVERITY {WARNING} [get_drc_checks NDRV-1]
# Disable opt_design to bypass Vivado 2025.1 bug with dvi2rgb v2.0 pRst net trimming
set_property STEPS.OPT_DESIGN.IS_ENABLED false [get_runs impl_1]

# Enable Power Optimization (is_enabled = true by default if opt_design runs, but we disabled opt_design, so we enable it specifically here if needed, or we just set strategy)
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Set aggressive physical synthesis for timing
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
if {[string match "*Complete*" $status]} {
    puts "============================================================"
    puts " SUCCESS: Bitstream Generated!"
    puts "============================================================"
} else {
    puts "============================================================"
    puts " ERROR: Bitstream Generation Failed. STATUS: $status"
    puts "============================================================"
    exit 1
}
exit
