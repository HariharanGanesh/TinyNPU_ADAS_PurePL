open_project {D:/Final year project/npu200jb/npu200jb.xpr}

puts "Cleaning old constraints..."
set user_xdcs [get_files -quiet -of_objects [get_filesets constrs_1] -filter {FILE_TYPE == XDC}]
if {$user_xdcs != ""} {
    remove_files $user_xdcs
}

puts "Adding Master Constraints File..."
cd {D:/Final year project}
add_files -fileset constrs_1 -norecurse tinynpu_master.xdc
set_property PROCESSING_ORDER LATE [get_files tinynpu_master.xdc]

puts "Resetting previous runs..."
reset_run synth_1

puts "Launching fresh Synthesis and Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

close_project
puts "BATCH COMPILATION COMPLETE!"
