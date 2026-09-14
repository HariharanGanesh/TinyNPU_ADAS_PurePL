open_project "D:/Final year project/vivado_2k200j_proj/tinynpu_2k200j.xpr"

puts "================================================="
puts " Starting Synthesis & Implementation..."
puts "================================================="

# Reset previous runs if any
reset_run synth_1

# Launch full build pipeline up to bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 8

# Wait for completion
wait_on_run impl_1

# Check if successful
set status [get_property STATUS [get_runs impl_1]]
if {[string match "*Complete*" $status]} {
    puts "================================================="
    puts " SUCCESS: Bitstream generated successfully!"
    puts "================================================="
} else {
    puts "================================================="
    puts " ERROR: Build failed. Check the logs."
    puts " STATUS: $status"
    puts "================================================="
    exit 1
}
exit
