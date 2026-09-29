# =============================================================================
# export_hw.tcl
# Exports XSA hardware handoff for Vitis/PYNQ deployment
# Run in Vivado Tcl console AFTER impl is complete:
#   source {d:/Final year project/export_hw.tcl}
# =============================================================================

set PROJ_DIR "D:/Final year project/vivado_system/tinynpu_pynq_system"
set BD_NAME  "tinynpu_system_bd"
set XSA_OUT  "D:/Final year project/tinynpu_system.xsa"

puts "\n=== Exporting Hardware (XSA) ==="

# Open the project if not already open
if {[catch {current_project} err]} {
    open_project "$PROJ_DIR/tinynpu_pynq_system.xpr"
}

# Make sure impl_1 is open
open_run impl_1 -quiet

# Export hardware with bitstream included
write_hw_platform \
    -fixed \
    -include_bit \
    -force \
    -file "$XSA_OUT"

if {[file exists $XSA_OUT]} {
    set size [file size $XSA_OUT]
    puts "\n✅ XSA exported successfully!"
    puts "   Path: $XSA_OUT"
    puts "   Size: [expr {$size / 1024 / 1024}] MB"
} else {
    puts "ERROR: XSA export failed."
}

puts "\n=== Done! ==="
puts "Next steps:"
puts "  1. For PYNQ: copy .bit + .hwh to board"
puts "  2. For Vitis: use $XSA_OUT as hardware platform"
