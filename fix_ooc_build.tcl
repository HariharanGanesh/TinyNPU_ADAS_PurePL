# Open the project
open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

# Reset ALL runs (including the buggy OOC child runs from the previous attempt)
foreach run [get_runs *] {
    reset_run $run
}

# Ensure Global Synthesis
set_property synth_checkpoint_mode None [get_files npu_system.bd]
generate_target all [get_files npu_system.bd]

# Relaunch Bitstream Generation globally
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "================================================="
puts " GLOBAL SYNTHESIS COMPLETE AND BITSTREAM READY!"
puts "================================================="
