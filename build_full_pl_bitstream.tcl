# =============================================================================
# build_full_pl_bitstream.tcl
# Automatically generates HDL wrapper, runs Synthesis, Implementation,
# and generates Bitstream for the Full PL TinyNPU design.
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Bitstream Build Script"
puts "======================================================="

# Open project
open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}

# Generate Block Design Targets & Wrapper
puts "\n[1/5] Regenerating BD Target Files and Top Wrapper..."
generate_target all [get_files npu_system.bd]
make_wrapper -files [get_files npu_system.bd] -top -force
export_ip_user_files -of_objects [get_files npu_system.bd] -no_script -sync -force -quiet

# Reset & Run Synthesis
puts "\n[2/5] Running Synthesis (synth_1)..."
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed. Check synth_1 logs."
    exit 1
}

# Reset & Run Implementation + Bitstream
puts "\n[3/5] Running Implementation & Writing Bitstream (impl_1)..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed. Check impl_1 logs."
    exit 1
}

# Reporting
puts "\n[4/5] Generating Timing & Utilization Reports..."
file mkdir {D:/Final year project/npu200jpmax/reports}
open_run impl_1
report_timing_summary -max_paths 20 -file {D:/Final year project/npu200jpmax/reports/impl_timing.rpt}
report_utilization -file {D:/Final year project/npu200jpmax/reports/impl_utilization.rpt}

puts "\n[5/5] BUILD COMPLETE!"
puts "Bitstream Location: D:/Final year project/npu200jpmax/npu200jpmax.runs/impl_1/npu_system_wrapper.bit"
puts "======================================================="
