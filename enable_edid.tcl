puts "Enabling Internal 720p EDID in dvi2rgb..."

# Find the dvi2rgb block and enable the internal EDID ROM
set dvi_block [get_bd_cells -hierarchical -filter {VLNV=~*digilentinc.com:ip:dvi2rgb:*}]

if {$dvi_block != ""} {
    # Set the Digilent EDID parameter to force the laptop to recognize it as a 720p monitor
    set_property -dict [list CONFIG.kEdidFileName {720p_edid.txt}] $dvi_block
    puts "Successfully enabled the EDID on $dvi_block!"
} else {
    puts "ERROR: Could not find the dvi2rgb block in the design!"
}

puts "=================================================="
puts "SCRIPT FINISHED! You can now Generate Bitstream!"
puts "=================================================="
