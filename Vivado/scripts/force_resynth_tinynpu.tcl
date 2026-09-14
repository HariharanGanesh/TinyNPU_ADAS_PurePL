## force_resynth_tinynpu.tcl
## Forces ONLY the tinynpu100 sub-synthesis to re-run with updated RTL
## (IP repo already has .clk(clk_postproc) fix in tinynpu_top.v)
## Then runs impl to close timing.

set PROJ "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"

puts "Opening project..."
open_project $PROJ

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Force re-synthesis of ONLY the tinynpu100 OOC sub-run
# (IP repo already has updated RTL - just the cached DCP needs to be refreshed)
puts "Resetting tinynpu100 sub-synthesis run..."
reset_run tinynpu_system_bd_tinynpu100_0_0_synth_1

# Reset top-level synth (will pick up new tinynpu100 DCP)
puts "Resetting top-level synthesis..."
reset_run synth_1

# Rebuild with post-route phys_opt strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

puts "Launching impl_1 -> write_bitstream (jobs=4)..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Waiting for build to complete (~35-45 min)..."
wait_on_run impl_1

# Check final timing
puts "=== Checking Final Timing ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts " Bitstream at: .../impl_1/tinynpu_system_bd_wrapper.bit"
} else {
    puts " Final WNS = $wns ns — share final_timing_summary.txt"
}
puts "=========================================================="
