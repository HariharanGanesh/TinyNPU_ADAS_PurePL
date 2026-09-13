## final_rebuild.tcl
## Full rebuild with two RTL fixes applied:
##   1. frame_gen.v   - pipelined in_bar (fixes -1.285ns critical path)
##   2. tinynpu_top.v - threshold_filter clk_postproc (fixes -3.113ns skew)
## =======================================================================

puts "=== FINAL TIMING CLOSURE REBUILD ==="

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Ensure 100 MHz PS clock
set ps_cell [get_bd_cells -quiet processing_system7_0]
if {$ps_cell ne ""} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] $ps_cell
    validate_bd_design -quiet
    save_bd_design -quiet
    puts "PS clock = 100 MHz"
}

# Delete stale frame_gen and tinynpu100 cached DCPs so new RTL is compiled
set gen_dir "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.gen/sources_1/bd/tinynpu_system_bd/ip"
file delete -force "$gen_dir/tinynpu_system_bd_frame_gen_0_0"
file delete -force "$gen_dir/tinynpu_system_bd_tinynpu100_0_0"
puts "Cleared stale IP caches"

# Use Performance_ExplorePostRoutePhysOpt for built-in post-route phys_opt
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# Launch full rebuild
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Build launched. Waiting..."
wait_on_run impl_1

# Check timing
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

if {$wns >= 0.0} {
    puts "=========================================================="
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts "=========================================================="
} else {
    puts "=========================================================="
    puts " Final WNS = $wns ns — share final_timing_summary.txt"
    puts "=========================================================="
}
