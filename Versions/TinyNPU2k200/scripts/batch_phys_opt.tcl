## batch_phys_opt.tcl — runs standalone against the routed checkpoint
## Usage: vivado -mode batch -source batch_phys_opt.tcl

set DCP "D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper_routed.dcp"
set OUT_BIT "D:/Final year project/vivado_system/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper.bit"

puts "Opening routed checkpoint..."
open_checkpoint $DCP

puts "Running phys_opt_design -directive AggressiveExplore ..."
phys_opt_design -directive AggressiveExplore

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
puts "POST PHYS-OPT WNS = $wns ns"

report_timing_summary -file "D:/Final year project/post_phys_opt_timing.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/post_phys_opt_paths.txt"

if {$wns >= 0.0} {
    puts "======================================================"
    puts "SUCCESS: Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts "======================================================"
    write_bitstream -force $OUT_BIT
    puts "Bitstream written: $OUT_BIT"
} else {
    puts "INFO: WNS = $wns ns after phys_opt. Writing timing report for analysis."
    puts "Share post_phys_opt_timing.txt for next step."
}
