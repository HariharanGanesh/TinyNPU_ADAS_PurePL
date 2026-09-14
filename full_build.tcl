open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

puts "=== Step 1: Regenerating ALL Block Design targets ==="
open_bd_design [get_files npu_system.bd]
update_compile_order -fileset sources_1

# Force full regeneration of all BD outputs (wrapper, IP netlists, constraints)
generate_target all [get_files npu_system.bd]
export_ip_user_files -of_objects [get_files npu_system.bd] -no_script -sync -force -quiet

# Regenerate the wrapper HDL
make_wrapper -files [get_files npu_system.bd] -top -force
set wrapper [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == "Verilog" && NAME =~ "*npu_system_wrapper*"}]
if {$wrapper eq ""} {
    # Add wrapper if not already in project
    add_files -norecurse [get_files -of_objects [get_filesets sources_1] npu_system_wrapper.v]
}
set_property top npu_system_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "BD regeneration complete."

puts "=== Step 2: Clean Synthesis (12 jobs) ==="
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1

set synth_prog [get_property PROGRESS [get_runs synth_1]]
puts "Synthesis Progress: $synth_prog"
if {$synth_prog != "100%"} {
    puts "CRITICAL: Synthesis FAILED. Check reports."
    exit 1
}
puts "Synthesis PASSED."

puts "=== Step 3: Implementation + Bitstream (Performance_Explore, 12 jobs) ==="
set_property STRATEGY "Performance_Explore" [get_runs impl_1]
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

set impl_prog [get_property PROGRESS [get_runs impl_1]]
puts "Implementation Progress: $impl_prog"
if {$impl_prog != "100%"} {
    puts "CRITICAL: Implementation FAILED. Check reports."
    exit 1
}

puts "=== Step 4: Saving Reports ==="
open_run impl_1 -name impl_1
report_timing_summary -max_paths 20 -file "D:/Final year project/npu200jpmax/reports/impl_timing.rpt" -warn_on_violation
report_utilization    -file "D:/Final year project/npu200jpmax/reports/impl_utilization.rpt"
report_drc            -file "D:/Final year project/npu200jpmax/reports/impl_drc.rpt"
report_power          -file "D:/Final year project/npu200jpmax/reports/impl_power.rpt"

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts ""
puts "=============================================="
if {$wns >= 0} {
    puts " FULL GREEN BUILD COMPLETE!"
    puts " WNS = +$wns ns (Timing CLOSED)"
} else {
    puts " WARNING: Timing NOT closed. WNS = $wns ns"
}
puts " Bitstream: npu200jpmax/npu200jpmax.runs/impl_1/npu_system_wrapper.bit"
puts "=============================================="
