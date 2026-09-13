## =============================================================================
## close_timing.tcl
## Two-stage timing closure script:
##   Stage 1: Post-route phys_opt_design -directive AggressiveExplore
##   Stage 2: If still failing, full rebuild with new pipelined frame_gen RTL
## =============================================================================

puts "=== STAGE 1: Post-Route Physical Optimization ==="

# Open the routed run (already done, just make sure)
if {[catch {open_run impl_1} err]} {
    puts "INFO: open_run: $err (may already be open)"
}

# Check current WNS before phys_opt
set pre_wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
puts "Pre phys_opt WNS = $pre_wns ns"

# Run aggressive post-route physical optimization
puts "Running phys_opt_design -directive AggressiveExplore ..."
phys_opt_design -directive AggressiveExplore

# Check WNS after phys_opt
set post_wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
puts "Post phys_opt WNS = $post_wns ns"

# Report timing
report_timing_summary -file "D:/Final year project/post_phys_opt_timing.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/post_phys_opt_paths.txt"
puts "Timing reports written."

if {$post_wns >= 0.0} {
    puts "==================================================="
    puts "SUCCESS: Timing CLOSED at 100 MHz! WNS=$post_wns ns"
    puts "==================================================="
    write_bitstream -force {D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper.bit}
    puts "Bitstream written successfully!"
} else {
    puts "==================================================="
    puts "INFO: phys_opt alone not enough (WNS=$post_wns ns)"
    puts "Launching Stage 2: Full rebuild with new frame_gen RTL"
    puts "==================================================="

    # Stage 2: Full rebuild - the stale DCP is already deleted,
    # so Vivado will re-elaborate frame_gen from the updated RTL.
    # Also disable tinynpu.xdc and ensure 100MHz clock.

    # Disable problematic XDC
    set xdc_files [get_files -quiet "*tinynpu.xdc"]
    if {$xdc_files ne ""} {
        set_property IS_ENABLED 0 $xdc_files
        puts "Disabled tinynpu.xdc"
    }

    # Set PS to 100 MHz
    set ps_cell [get_bd_cells -quiet processing_system7_0]
    if {$ps_cell ne ""} {
        set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] $ps_cell
        validate_bd_design -quiet
        save_bd_design -quiet
        puts "PS clock set to 100 MHz"
    }

    # Use Performance_ExplorePostRoutePhysOpt strategy for better timing closure
    set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
    set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

    # Full reset and rebuild
    reset_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1

    # Check final timing
    open_run impl_1
    set final_wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
    report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
    report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

    if {$final_wns >= 0.0} {
        puts "==================================================="
        puts "SUCCESS: Timing CLOSED at 100 MHz! WNS=$final_wns ns"
        puts "==================================================="
    } else {
        puts "==================================================="
        puts "RESULT: Final WNS=$final_wns ns - Share final_timing_summary.txt"
        puts "==================================================="
    }
}
