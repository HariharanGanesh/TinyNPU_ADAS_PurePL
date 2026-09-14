# =============================================================================
# fix_bd_addresses.tcl
# Fixes all Address Editor issues for the Full PL JTAG-based TinyNPU design.
# Run from Vivado Tcl Console: source {D:/Final year project/fix_bd_addresses.tcl}
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Address Map Fix Script"
puts "======================================================="

# Step 1: Fix the dangling M01_AXI on axi_mem_intercon_1
puts ""
puts "Step 1: Reducing axi_mem_intercon_1 to 1 master interface..."
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_mem_intercon_1]
puts "        Done."

# Step 2: Wipe all existing address assignments cleanly
puts ""
puts "Step 2: Clearing all existing address assignments..."
foreach space [get_bd_addr_spaces] {
    foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $space] -quiet] {
        catch { unassign_bd_address $seg }
    }
}
puts "        Done."

# Step 3: JTAG Master -> all peripherals
puts ""
puts "Step 3: Assigning JTAG Master address space..."

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs tinynpu_0/s_axi/reg0] \
    -range 64K -offset 0x40000000
puts "        tinynpu_0/s_axi  -> 0x40000000 (64K)"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] \
    -range 64K -offset 0x41E00000
puts "        axi_dma_0 CSR    -> 0x41E00000 (64K)"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs vtc_0/ctrl/Reg] \
    -range 64K -offset 0x44A00000
puts "        vtc_0/ctrl       -> 0x44A00000 (64K)"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        axi_bram_ctrl_0  -> 0xC0000000 (8K) - write weights"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] \
    -range 8K -offset 0xC0002000
puts "        axi_bram_ctrl_1  -> 0xC0002000 (8K) - debug read"

# Step 4: DMA -> BRAM Port A only
puts ""
puts "Step 4: Assigning DMA address space..."
assign_bd_address \
    -target_address_space /axi_dma_0/Data_S2MM \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        axi_bram_ctrl_0  -> 0xC0000000 (8K)"

# Step 5: NPU -> BRAM Port B only
puts ""
puts "Step 5: Assigning NPU Master address space..."
assign_bd_address \
    -target_address_space /tinynpu_0/m_axi \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        axi_bram_ctrl_1  -> 0xC0000000 (8K)"

# Step 6: Validate and Save
puts ""
puts "Step 6: Validating block design..."
validate_bd_design
save_bd_design

puts ""
puts "======================================================="
puts " DONE - Final Address Map:"
puts "   JTAG -> NPU CSR     : 0x40000000"
puts "   JTAG -> DMA CSR     : 0x41E00000"
puts "   JTAG -> VTC CSR     : 0x44A00000"
puts "   JTAG -> BRAM ctrl_0 : 0xC0000000 (write weights)"
puts "   JTAG -> BRAM ctrl_1 : 0xC0002000 (debug)"
puts "   DMA  -> BRAM ctrl_0 : 0xC0000000 (video frames)"
puts "   NPU  -> BRAM ctrl_1 : 0xC0000000 (read weights)"
puts "======================================================="
