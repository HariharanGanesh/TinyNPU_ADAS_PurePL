# =============================================================================
# diagnose_bd.tcl
# Prints the physical reachability of each AXI master in the design.
# Run from Vivado Tcl Console:
#   source {D:/Final year project/diagnose_bd.tcl}
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Block Design Diagnostic"
puts "======================================================="

# --- What can JTAG reach? ---
puts ""
puts "JTAG master (/jtag_axi_0/Data) can reach these slaves:"
set jtag_segs [get_bd_addr_segs -addressables \
    -of_objects [get_bd_addr_spaces /jtag_axi_0/Data] -quiet]
if {$jtag_segs eq ""} {
    puts "  !! NOTHING - jtag_axi_0 has no slaves connected !!"
} else {
    foreach seg $jtag_segs { puts "  -> $seg" }
}

# --- What can DMA reach? ---
puts ""
puts "DMA S2MM (/axi_dma_0/Data_S2MM) can reach:"
set dma_segs [get_bd_addr_segs -addressables \
    -of_objects [get_bd_addr_spaces /axi_dma_0/Data_S2MM] -quiet]
if {$dma_segs eq ""} {
    puts "  !! NOTHING - DMA S2MM has no memory connected !!"
} else {
    foreach seg $dma_segs { puts "  -> $seg" }
}

# --- What can NPU reach? ---
puts ""
puts "NPU master (/tinynpu_0/m_axi) can reach:"
set npu_segs [get_bd_addr_segs -addressables \
    -of_objects [get_bd_addr_spaces /tinynpu_0/m_axi] -quiet]
if {$npu_segs eq ""} {
    puts "  !! NOTHING - NPU m_axi has no memory connected !!"
} else {
    foreach seg $npu_segs { puts "  -> $seg" }
}

# --- Show all interface connections ---
puts ""
puts "All AXI interface connections in the design:"
foreach net [get_bd_intf_nets] {
    set pins [get_bd_intf_pins -of_objects $net]
    if {[llength $pins] >= 2} {
        puts "  [lindex $pins 0]  <->  [lindex $pins 1]"
    }
}

puts ""
puts "======================================================="
puts " Paste this output and send it to get the exact fix!"
puts "======================================================="
