# =============================================================================
# fix_full_pl.tcl
# Comprehensive fix: physical wiring + address assignment for Full PL design.
# Run from Vivado Tcl Console:
#   source {D:/Final year project/fix_full_pl.tcl}
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Complete Wiring and Address Fix"
puts "======================================================="

# -----------------------------------------------------------------------
# STEP 1: Fix axi_mem_intercon_1 - remove dangling M01_AXI
# -----------------------------------------------------------------------
puts ""
puts "Step 1: Fixing axi_mem_intercon_1 (removing dangling master port)..."
catch {
    set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_mem_intercon_1]
    puts "        axi_mem_intercon_1 now has 1 master port."
} err
if {$err ne ""} { puts "        WARNING: $err" }

# -----------------------------------------------------------------------
# STEP 2: Ensure axi_csr_intercon has 4 master ports
# Ports: M00=DMA CSR, M01=NPU CSR, M02=VTC CSR, M03=BRAM ctrl_0
# -----------------------------------------------------------------------
puts ""
puts "Step 2: Ensuring axi_csr_intercon has 4 master ports..."
catch {
    set_property -dict [list CONFIG.NUM_MI {4}] [get_bd_cells axi_csr_intercon]
    puts "        axi_csr_intercon now has 4 master ports."
} err
if {$err ne ""} { puts "        WARNING: $err" }

# -----------------------------------------------------------------------
# STEP 3: Create missing physical connections
# -----------------------------------------------------------------------
puts ""
puts "Step 3: Creating missing physical AXI connections..."

# Connect axi_csr_intercon/M03_AXI -> axi_bram_ctrl_0/S_AXI
# This is what lets JTAG write the neural network weights into the BRAM
set existing [get_bd_intf_nets -of_objects \
    [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] -quiet]
if {$existing eq ""} {
    connect_bd_intf_net \
        [get_bd_intf_pins axi_csr_intercon/M03_AXI] \
        [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
    puts "        Connected: axi_csr_intercon/M03_AXI -> axi_bram_ctrl_0/S_AXI"
} else {
    puts "        OK: axi_bram_ctrl_0/S_AXI is already connected."
}

# Connect axi_mem_intercon/M00_AXI -> axi_bram_ctrl_1/S_AXI
# This is what lets the NPU's internal DMA read weights from the BRAM
set existing [get_bd_intf_nets -of_objects \
    [get_bd_intf_pins axi_bram_ctrl_1/S_AXI] -quiet]
if {$existing eq ""} {
    connect_bd_intf_net \
        [get_bd_intf_pins axi_mem_intercon/M00_AXI] \
        [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]
    puts "        Connected: axi_mem_intercon/M00_AXI -> axi_bram_ctrl_1/S_AXI"
} else {
    puts "        OK: axi_bram_ctrl_1/S_AXI is already connected."
}

# -----------------------------------------------------------------------
# STEP 4: Wire clocks and resets for both BRAM controllers
# -----------------------------------------------------------------------
puts ""
puts "Step 4: Wiring clocks and resets for BRAM controllers..."

set clk125  [get_bd_pins clk_wiz_0/clk_out1]
set rst_n   [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

foreach ctrl {axi_bram_ctrl_0 axi_bram_ctrl_1} {
    set clk_pin [get_bd_pins $ctrl/s_axi_aclk]
    set rst_pin [get_bd_pins $ctrl/s_axi_aresetn]
    if {[get_bd_nets -of_objects $clk_pin -quiet] eq ""} {
        connect_bd_net $clk125 $clk_pin
        puts "        Connected clock  -> $ctrl/s_axi_aclk"
    } else {
        puts "        OK: $ctrl/s_axi_aclk already clocked."
    }
    if {[get_bd_nets -of_objects $rst_pin -quiet] eq ""} {
        connect_bd_net $rst_n $rst_pin
        puts "        Connected resetn -> $ctrl/s_axi_aresetn"
    } else {
        puts "        OK: $ctrl/s_axi_aresetn already reset."
    }
}

# -----------------------------------------------------------------------
# STEP 5: Clear all address assignments
# -----------------------------------------------------------------------
puts ""
puts "Step 5: Clearing all existing address assignments..."
foreach space [get_bd_addr_spaces] {
    foreach seg [get_bd_addr_segs \
        -of_objects [get_bd_addr_spaces $space] -quiet] {
        catch { unassign_bd_address $seg }
    }
}
puts "        Done."

# -----------------------------------------------------------------------
# STEP 6: Assign JTAG master address space
# -----------------------------------------------------------------------
puts ""
puts "Step 6: Assigning JTAG Master address space..."

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs tinynpu_0/s_axi/reg0] \
    -range 64K -offset 0x40000000
puts "        tinynpu_0 CSR    -> 0x40000000"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] \
    -range 64K -offset 0x41E00000
puts "        axi_dma_0 CSR    -> 0x41E00000"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs vtc_0/ctrl/Reg] \
    -range 64K -offset 0x44A00000
puts "        vtc_0 CSR        -> 0x44A00000"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        BRAM ctrl_0      -> 0xC0000000 (write weights)"

assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] \
    -range 8K -offset 0xC0002000
puts "        BRAM ctrl_1      -> 0xC0002000 (debug read)"

# -----------------------------------------------------------------------
# STEP 7: Assign DMA address space (Port A only)
# -----------------------------------------------------------------------
puts ""
puts "Step 7: Assigning DMA S2MM address space..."

assign_bd_address \
    -target_address_space /axi_dma_0/Data_S2MM \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        BRAM ctrl_0      -> 0xC0000000"

# -----------------------------------------------------------------------
# STEP 8: Assign NPU master address space (Port B only)
# -----------------------------------------------------------------------
puts ""
puts "Step 8: Assigning NPU m_axi address space..."

assign_bd_address \
    -target_address_space /tinynpu_0/m_axi \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        BRAM ctrl_1      -> 0xC0000000"

# -----------------------------------------------------------------------
# STEP 9: Validate and Save
# -----------------------------------------------------------------------
puts ""
puts "Step 9: Validating and saving block design..."
validate_bd_design
save_bd_design

puts ""
puts "======================================================="
puts " COMPLETE - Next steps:"
puts "   1. Right-click npu_system.bd -> Generate HDL Wrapper"
puts "   2. Run Synthesis"
puts "   3. Run Implementation"
puts "   4. Generate Bitstream"
puts "======================================================="
