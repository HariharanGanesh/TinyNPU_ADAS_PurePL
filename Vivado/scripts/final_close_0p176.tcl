## final_close_0p176.tcl
## Opens the postroute_physopt checkpoint and runs one more focused
## phys_opt pass to close the remaining -0.176 ns violation.
## Key path: u_pooling -> u_bbox_decoder -> u_threshold_filter (fo=65 net)
## Target: Replicate the high-fanout valid_out_reg_0 net to reduce routing delay.

set DCP "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper_postroute_physopt.dcp"
set BIT "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper.bit"

puts "Opening post-route physopt checkpoint..."
open_checkpoint $DCP

set wns_before [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
puts "WNS before: $wns_before ns"

puts "Running phys_opt_design pass 1: AggressiveExplore..."
phys_opt_design -directive AggressiveExplore

set wns1 [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
puts "WNS after pass 1: $wns1 ns"

if {$wns1 < 0.0} {
    puts "Running phys_opt_design pass 2: AggressiveFanoutOpt (targets fo=65 net)..."
    phys_opt_design -directive AggressiveFanoutOpt
    set wns2 [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
    puts "WNS after pass 2: $wns2 ns"
} else {
    set wns2 $wns1
}

if {$wns2 < 0.0} {
    puts "Running phys_opt_design pass 3: AlternateReplication..."
    phys_opt_design -directive AlternateReplication
    set wns3 [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
    puts "WNS after pass 3: $wns3 ns"
} else {
    set wns3 $wns2
}

set final_wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]

report_timing_summary -file "D:/Final year project/final_phys_opt2_timing.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_phys_opt2_paths.txt"

puts ""
puts "==========================================================="
if {$final_wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $final_wns ns"
    write_bitstream -force $BIT
    puts " Bitstream written: $BIT"
} else {
    puts " Final WNS = $final_wns ns"
    puts " Timing reports: final_phys_opt2_timing.txt"
}
puts "==========================================================="
