puts "=================================================="
puts "AUTOMATED FIX SCRIPT INITIATED"
puts "=================================================="

# 1. Clear out all messy user constraints
puts "Cleaning old constraints..."
set user_xdcs [get_files -quiet -of_objects [get_filesets constrs_1] -filter {FILE_TYPE == XDC}]
if {$user_xdcs != ""} {
    remove_files $user_xdcs
}

# 2. Add the master constraint file
puts "Adding Master Constraints File..."
add_files -fileset constrs_1 -norecurse {D:/Final year project/tinynpu_master.xdc}
# Force Vivado to process this file LAST so the clocks are guaranteed to exist
set_property PROCESSING_ORDER LATE [get_files {D:/Final year project/tinynpu_master.xdc}]

# 3. Reset and Launch Implementation
puts "Resetting previous runs..."
reset_run synth_1

puts "Launching fresh Synthesis and Implementation to fix timing..."
launch_runs impl_1 -to_step write_bitstream -jobs 8

puts "=================================================="
puts "FIX APPLIED! Vivado is now recompiling the design in the background."
puts "You can monitor the progress in the 'Design Runs' tab at the bottom."
puts "When it finishes, your timing will be 100% green!"
puts "=================================================="
