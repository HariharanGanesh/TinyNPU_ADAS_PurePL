# launch_pmax.tcl — TinyNPU200JPMAX Build (Clone + RTL Swap Strategy)
# FIX: All paths with spaces wrapped in {} to prevent TCL word-splitting

# Open the cloned project
open_project {D:/Final year project/npu200jpmax/npu200jb.xpr}

# Ensure top module is set correctly
set_property top npu_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Add PMAX XDC constraints (all bugs pre-baked)
# Note: existing hdmi_pins.xdc from npu200jb already contains the fixes.
# We skip re-adding to avoid duplicates — the cloned project inherits constraints.

# Flush ALL OOC synthesis caches — forces NPU300PM RTL to be re-synthesized
# (Critical: Vivado silently reuses stale cached netlists without this)
foreach run [get_runs -filter {IS_SYNTHESIS == 1 && NAME != "synth_1"}] {
    catch { reset_run $run }
}
reset_run synth_1

# Performance strategy
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

puts "======================================"
puts "  TinyNPU200JPMAX / NPU300PM Build"
puts "  26x8 = 208 MACs, DSP48E1 forced"
puts "  Clock: 125 MHz | Budget <=215 DSPs"
puts "======================================"

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

# Report final timing
open_run impl_1
set wns [get_property STATS.WNS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]

puts "======================================"
puts "  FINAL TIMING — TinyNPU200JPMAX"
puts "  WNS = $wns ns"
puts "  TNS = $tns ns"
puts "  WHS = $whs ns"
if {$wns >= 0 && $whs >= 0} {
    puts "  STATUS: TIMING CLOSURE PASSED"
} else {
    puts "  STATUS: TIMING FAILED - review report"
}
puts "======================================"
exit
