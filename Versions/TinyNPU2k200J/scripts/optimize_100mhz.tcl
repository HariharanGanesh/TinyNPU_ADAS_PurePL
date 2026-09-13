set proj_path "D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set proj_name [file rootname [file tail $proj_path]]
if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
    open_project "$proj_path"
}

puts "--- Restoring PS Clock to 100 MHz ---"
set ps_cell [get_bd_cells -quiet processing_system7_0]
if {$ps_cell eq ""} { set ps_cell [get_bd_cells -quiet ps7] }
if {$ps_cell ne ""} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] $ps_cell
    puts "Set $ps_cell FCLK_CLK0 to 100 MHz"
}

# Save BD
validate_bd_design -quiet
save_bd_design -quiet

puts "--- Applying Aggressive Timing & Power Optimizations ---"

# 1. Synthesis: Optimize for Performance
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# 2. Implementation: Explore algorithms to close timing
set_property strategy Performance_Explore [get_runs impl_1]

# 3. Enable post-place Power Optimization
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# 4. Enable aggressive Physical Optimization (Register Retiming to break long paths automatically)
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# 5. Route: Explore algorithms
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

puts "--- Restarting Build ---"
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "INFO: Aggressive optimization build started! This will take a little longer than usual."
