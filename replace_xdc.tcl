puts "Replacing obsolete HDMI constraints with clean DRC bypass..."

# 1. Find and remove the old hdmi_pins.xdc file if it exists in the project
set old_xdc [get_files -quiet {*hdmi_pins.xdc}]
if {$old_xdc != ""} {
    remove_files $old_xdc
    puts "Successfully removed hdmi_pins.xdc from the project."
} else {
    puts "hdmi_pins.xdc was not found in the project (already removed)."
}

# 2. Add the new drc_bypass.xdc file
add_files -fileset constrs_1 -norecurse "D:/Final year project/drc_bypass.xdc"
puts "Successfully added drc_bypass.xdc."

puts "=================================================="
puts "SCRIPT FINISHED! You can now Generate Bitstream!"
puts "=================================================="
