puts "Restoring the DDC (EDID) physical wire connection..."

# 1. Find the DDC pin on the dvi2rgb block
set ddc_pin [get_bd_intf_pins -hierarchical -filter {NAME=~*/dvi2rgb_0/DDC}]

if {$ddc_pin != ""} {
    # 2. Force the pin to be external so it connects to the HDMI port
    make_bd_intf_pins_external $ddc_pin
    puts "Successfully restored the DDC wire to the outside world!"
    puts "=================================================="
    puts "IMPORTANT: Look at the top of your Block Design window."
    puts "If you see a green 'Run Connection Automation' banner, click it!"
    puts "If not, you can safely Generate Bitstream now."
    puts "=================================================="
} else {
    puts "ERROR: Could not find the DDC pin! Make sure your Block Design is open."
}
