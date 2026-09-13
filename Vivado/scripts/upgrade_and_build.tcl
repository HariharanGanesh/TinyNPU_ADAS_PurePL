## upgrade_and_build.tcl
## The definitive way to break Vivado's IP cache: bump the IP version!

set PROJ "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"

puts "=== STEP 1: Re-packaging IP to version 2.1 ==="
source "D:/Final year project/package_ip.tcl"

puts "=== STEP 2: Upgrading Block Design ==="
open_project $PROJ

# Refresh catalog to see v2.1
set_property ip_repo_paths "D:/ip_repo" [current_project]
update_ip_catalog -rebuild

# Find the IP and upgrade it
set tinynpu_ip [get_ips -all *tinynpu100*]
if {$tinynpu_ip ne ""} {
    puts "Upgrading IP: $tinynpu_ip"
    upgrade_ip $tinynpu_ip
} else {
    puts "WARNING: Could not find tinynpu IP in block design to upgrade"
}

# Regenerate target to force writing new .v wrapper files in .gen directory
puts "Generating block design targets..."
generate_target all [get_files *.bd]

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Reset synth
reset_run synth_1

# Best timing strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

puts "=== STEP 3: Launching Implementation ==="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "=== Checking Final Timing ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary_v21.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths_v21.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
} else {
    puts " Final WNS = $wns ns -- check final_timing_summary_v21.txt"
}
puts "=========================================================="
