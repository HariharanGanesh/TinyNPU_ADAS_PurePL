## definitive_rebuild.tcl
## Definitive timing closure build:
##   1. IP cache DISABLED (forces genuine re-synthesis from ip_repo source)
##   2. tinynpu100 sub-synth reset (picks up .clk(clk_postproc) fix)
##   3. Full impl with Performance_ExplorePostRoutePhysOpt
##
## IP repo has confirmed fix: threshold_filter .clk(clk_postproc) at line 781
## This eliminates the -3.351ns clock skew that caused WNS=-0.176ns

set PROJ "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"

puts "Opening project..."
open_project $PROJ

## CRITICAL: disable IP synthesis cache so tinynpu100 compiles from source
puts "Disabling IP synthesis cache..."
config_ip_cache -disable_cache

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Refresh ip_repo
set_property ip_repo_paths "D:/ip_repo" [current_project]
update_ip_catalog -rebuild -quiet
puts "IP catalog refreshed"

# Force tinynpu100 sub-synthesis to re-run from source
puts "Resetting tinynpu100 sub-synthesis (cache disabled = genuine recompile)..."
reset_run tinynpu_system_bd_tinynpu100_0_0_synth_1

# Reset top-level synth
puts "Resetting synth_1..."
reset_run synth_1

# Best timing strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

puts "Launching full rebuild (jobs=4)..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Waiting... (~40-50 min - tinynpu100 compiling fresh from source)"
wait_on_run impl_1

puts "=== Checking Final Timing ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts " Bitstream: .../impl_1/tinynpu_system_bd_wrapper.bit"
} else {
    puts " Final WNS = $wns ns -- check final_timing_summary.txt"
}
puts "=========================================================="
