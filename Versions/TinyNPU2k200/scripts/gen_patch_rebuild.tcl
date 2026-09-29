## gen_patch_rebuild.tcl
## The .gen/sources/ipshared/bd96/src/tinynpu_top.v has been DIRECTLY patched
## to use .clk(clk_postproc) for threshold_filter.
## The sub-synth run dir was deleted so Vivado MUST re-synthesize from the patched source.
## This is the definitive timing closure run.

set PROJ "D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.xpr"

puts "Opening project..."
open_project $PROJ

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Reset main synth to pick up new DCP from sub-synth
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
wait_on_run impl_1

puts "=== Checking Final Timing ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary_genfix.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths_genfix.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts " Bitstream: .../impl_1/tinynpu_system_bd_wrapper.bit"
} else {
    puts " Final WNS = $wns ns -- check final_timing_summary_genfix.txt"
}
puts "=========================================================="
