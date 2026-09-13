## =============================================================================
## TinyNPU200 — Full Build Script
## Project: vivado_npu200j_proj / TinyNPU200J
## Target:  PYNQ-Z2 (XC7Z020CLG400-1)
## Tool:    Vivado 2025.1
## =============================================================================
##
## USAGE (from Vivado Tcl console or batch mode):
##   vivado -mode batch -source "Versions/TinyNPU200J/scripts/build_npu200j.tcl"
##
## Or from project root:
##   Double-click: Generate_TinyNPU200J_Bitstream.bat
##
## WHAT THIS SCRIPT DOES:
##   1. Creates a new Vivado project: vivado_npu200j_proj/npu200j.xpr
##   2. Adds all TinyNPU200J RTL source files
##   3. Adds all constraint files (HDMI pins + timing)
##   4. Runs synthesis → implementation → bitstream generation
##   5. Reports timing summary and resource utilization
## =============================================================================

set project_name    "npu200j"
set project_dir     "[file normalize {d:/Final year project/vivado_npu200j_green_proj}]"
set rtl_dir         "[file normalize {d:/Final year project/Versions/TinyNPU200J/rtl/src}]"
set constraints_dir "[file normalize {d:/Final year project/Versions/TinyNPU200J/constraints}]"
set part            "xc7z020clg400-1"

# =============================================================================
# Step 1: Create Project
# =============================================================================
create_project ${project_name} ${project_dir} -part ${part} -force
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]

puts "INFO: Created project ${project_name} at ${project_dir}"

# =============================================================================
# Step 2: Add RTL Sources
# =============================================================================
# Core RTL — Technology-Independent
add_files -norecurse [list \
    ${rtl_dir}/pe/processing_element.v \
    ${rtl_dir}/systolic_array/systolic_array.v \
    ${rtl_dir}/activation/activation_unit.v \
    ${rtl_dir}/activation/hardswish_lut.v \
    ${rtl_dir}/activation/sigmoid_lut.v \
    ${rtl_dir}/activation/piecewise_sigmoid.v \
    ${rtl_dir}/pooling/pooling_unit.v \
    ${rtl_dir}/quantization/requantization_unit.v \
    ${rtl_dir}/quantization/threshold_filter.v \
    ${rtl_dir}/pe/bbox_decoder.v \
    ${rtl_dir}/buffers/activation_buffer.v \
    ${rtl_dir}/buffers/weight_buffer.v \
    ${rtl_dir}/buffers/output_buffer.v \
    ${rtl_dir}/buffers/cdc_async_fifo.v \
    ${rtl_dir}/axi/axis_sink.v \
    ${rtl_dir}/axi/axis_source.v \
    ${rtl_dir}/axi/axi4_lite_slave.v \
    ${rtl_dir}/dma/dma_controller.v \
    ${rtl_dir}/control/npu_controller.v \
    ${rtl_dir}/dw_engine/dw_line_buffer.v \
    ${rtl_dir}/core/sram_1rw.v \
    ${rtl_dir}/core/sram_2rw.v \
    ${rtl_dir}/core/tinynpu_icg.v \
    ${rtl_dir}/core/rst_sync.v \
    ${rtl_dir}/clocking/clk_gate_bufgce.v \
    ${rtl_dir}/clocking/pixel_pll.v \
    ${rtl_dir}/osd/font_rom.v \
    ${rtl_dir}/osd/hardware_osd_mixer.v \
    ${rtl_dir}/osd/object_tracker.v \
    ${rtl_dir}/frontend/frame_gen.v \
    ${rtl_dir}/frontend/result_capture.v \
    ${rtl_dir}/top/tinynpu_top.v \
    ${rtl_dir}/wrappers/fpga/tinynpu_fpga_wrapper.v \
    ${rtl_dir}/test_wrappers/tinynpu_hdmi_top.v \
]

# Set synthesis top module
set_property top tinynpu_hdmi_top [current_fileset]
update_compile_order -fileset sources_1

puts "INFO: Added [llength [get_files -filter {FILE_TYPE == Verilog}]] Verilog source files"

# =============================================================================
# Step 3: Add IP (sys_pll, pynq_dvi_rx, pynq_dvi_tx)
# These IPs must be pre-generated or available in the IP repository.
# =============================================================================
# sys_pll: Clocking Wizard IP (125MHz → 195MHz + 200MHz)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name sys_pll
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.NUM_OUT_CLKS {2} \
] [get_ips sys_pll]

# Add the Digilent IP repository
set_property ip_repo_paths [list "[file normalize {D:/Final year project/Shared/IP/digilent-vivado-library/ip}]"] [current_project]
update_ip_catalog

# Instantiate Digilent IPs (omit version to auto-select latest from repo)
create_ip -name dvi2rgb -vendor digilentinc.com -library ip -module_name pynq_dvi_rx
create_ip -name rgb2dvi -vendor digilentinc.com -library ip -module_name pynq_dvi_tx
set_property -dict [list CONFIG.kClkRange {2}] [get_ips pynq_dvi_tx]

puts "INFO: IP configuration complete"

# =============================================================================
# Step 4: Add Constraints
# =============================================================================
add_files -fileset constrs_1 -norecurse [list \
    ${constraints_dir}/hdmi_pins.xdc \
    ${constraints_dir}/pynq_z2_pins.xdc \
    ${constraints_dir}/tinynpu_pynq200.xdc \
]

puts "INFO: Added constraint files"

# =============================================================================
# Step 5: Synthesis
# =============================================================================
puts "INFO: Starting synthesis at [clock format [clock seconds] -format {%H:%M:%S}]"

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-flatten_hierarchy full} \
    -objects [get_runs synth_1]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "ERROR: Synthesis FAILED. Check synthesis log."
}

puts "INFO: Synthesis complete at [clock format [clock seconds] -format {%H:%M:%S}]"
open_run synth_1

# Report synthesis resource utilization
report_utilization -file "${project_dir}/npu200j_synth_util.rpt"
puts "INFO: Synthesis utilization report: ${project_dir}/npu200j_synth_util.rpt"

# =============================================================================
# Step 6: Implementation
# =============================================================================
puts "INFO: Starting implementation at [clock format [clock seconds] -format {%H:%M:%S}]"

set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE ExploreWithHoldFix [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
# Removed extra phys_opt_design argument

launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[string match "*Failed*" [get_property STATUS [get_runs impl_1]]]} {
    error "ERROR: Implementation FAILED. Check implementation log."
}
if {[string match "*Error*" [get_property STATUS [get_runs impl_1]]]} {
    error "ERROR: Implementation FAILED. Check implementation log."
}
puts "Implementation finished. Note: Timing may have failed, but continuing to bitstream."

puts "INFO: Implementation complete at [clock format [clock seconds] -format {%H:%M:%S}]"
open_checkpoint "${project_dir}/${project_name}.runs/impl_1/tinynpu_hdmi_top_routed.dcp"

# =============================================================================
# Step 7: Timing Analysis
# =============================================================================
set timing_rpt "${project_dir}/npu200j_timing.rpt"
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 -input_pins -routable_nets \
    -file ${timing_rpt}

# Check WNS
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "INFO: Worst Negative Slack (WNS) = ${wns} ns"

if {[expr {$wns < 0}]} {
    puts "WARNING: TIMING NOT MET! WNS = ${wns} ns. Review timing report: ${timing_rpt}"
} else {
    puts "SUCCESS: Timing CLOSED. WNS = ${wns} ns (positive = margin)"
}

report_utilization -file "${project_dir}/npu200j_impl_util.rpt"
report_drc -file "${project_dir}/npu200j_drc.rpt"
report_power -file "${project_dir}/npu200j_power.rpt"

puts "INFO: Reports saved to ${project_dir}/"

# =============================================================================
# Step 8: Bitstream Generation
# =============================================================================
puts "INFO: Generating bitstream at [clock format [clock seconds] -format {%H:%M:%S}]"

write_bitstream -force "${project_dir}/${project_name}.runs/impl_1/tinynpu_hdmi_top.bit"
set bit_file "${project_dir}/${project_name}.runs/impl_1/tinynpu_hdmi_top.bit"
if {[file exists ${bit_file}]} {
    puts "SUCCESS: Bitstream generated: ${bit_file}"
    # Copy to project root for easy access
    file copy -force ${bit_file} "[file normalize {d:/Final year project}]/TinyNPU200.bit"
    puts "INFO: Bitstream copied to: d:/Final year project/TinyNPU200.bit"
} else {
    error "ERROR: Bitstream NOT generated. Check implementation log."
}

puts "============================================================"
puts " TinyNPU200 Build Complete"
puts " WNS = ${wns} ns"
puts " Bitstream: d:/Final year project/TinyNPU200.bit"
puts "============================================================"
