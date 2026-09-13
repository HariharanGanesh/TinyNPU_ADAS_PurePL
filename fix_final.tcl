# =============================================================================
# fix_final.tcl
# Definitive fix based on diagnostic output.
# Run from Vivado Tcl Console:
#   source {D:/Final year project/fix_final.tcl}
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Definitive Fix Script"
puts "======================================================="

# Get clock and reset pins (adjust names if Vivado complains)
set clk         [get_bd_pins clk_wiz_0/clk_out1]
set periph_rst  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
set intercon_rst [get_bd_pins proc_sys_reset_0/interconnect_aresetn]

# -----------------------------------------------------------------------
# STEP 1: Expand axi_csr_intercon to 4 master ports
# Currently: M00=NPU CSR, M01=DMA CSR, M02=VTC CSR
# Adding:    M03 -> will route to BRAM via axi_mem_intercon_1
# -----------------------------------------------------------------------
puts ""
puts "Step 1: Expanding axi_csr_intercon to 4 masters..."
set_property -dict [list CONFIG.NUM_MI {4}] [get_bd_cells axi_csr_intercon]
puts "        Done."

# -----------------------------------------------------------------------
# STEP 2: Expand axi_mem_intercon_1 to 2 slave ports
# Currently: S00=DMA S2MM -> M00=bram_ctrl_0
# Adding:    S01 <- from axi_csr_intercon/M03 (JTAG writes weights)
# -----------------------------------------------------------------------
puts ""
puts "Step 2: Expanding axi_mem_intercon_1 to 2 slave ports..."
set_property -dict [list CONFIG.NUM_SI {2}] [get_bd_cells axi_mem_intercon_1]
puts "        Done."

# -----------------------------------------------------------------------
# STEP 3: Connect axi_csr_intercon/M03 -> axi_mem_intercon_1/S01
# This is the physical wire that lets JTAG reach bram_ctrl_0
# -----------------------------------------------------------------------
puts ""
puts "Step 3: Connecting JTAG path to BRAM..."
catch {
    connect_bd_intf_net \
        [get_bd_intf_pins axi_csr_intercon/M03_AXI] \
        [get_bd_intf_pins axi_mem_intercon_1/S01_AXI]
    puts "        Connected: axi_csr_intercon/M03_AXI -> axi_mem_intercon_1/S01_AXI"
} err
if {$err ne ""} { puts "        Note: $err (may already be connected)" }

# -----------------------------------------------------------------------
# STEP 4: Wire clocks/resets for all new ports
# The old AXI Interconnect IP needs every port clocked individually
# -----------------------------------------------------------------------
puts ""
puts "Step 4: Wiring clocks and resets..."

# axi_csr_intercon global clock/reset
foreach pin [list \
    axi_csr_intercon/ACLK \
    axi_csr_intercon/S00_ACLK \
    axi_csr_intercon/M00_ACLK \
    axi_csr_intercon/M01_ACLK \
    axi_csr_intercon/M02_ACLK \
    axi_csr_intercon/M03_ACLK] {
    catch { connect_bd_net $clk [get_bd_pins $pin] }
}
foreach pin [list \
    axi_csr_intercon/ARESETN \
    axi_csr_intercon/S00_ARESETN \
    axi_csr_intercon/M00_ARESETN \
    axi_csr_intercon/M01_ARESETN \
    axi_csr_intercon/M02_ARESETN \
    axi_csr_intercon/M03_ARESETN] {
    catch { connect_bd_net $periph_rst [get_bd_pins $pin] }
}

# axi_mem_intercon_1 - new S01 port
foreach pin [list \
    axi_mem_intercon_1/ACLK \
    axi_mem_intercon_1/S00_ACLK \
    axi_mem_intercon_1/S01_ACLK \
    axi_mem_intercon_1/M00_ACLK] {
    catch { connect_bd_net $clk [get_bd_pins $pin] }
}
foreach pin [list \
    axi_mem_intercon_1/ARESETN \
    axi_mem_intercon_1/S00_ARESETN \
    axi_mem_intercon_1/S01_ARESETN \
    axi_mem_intercon_1/M00_ARESETN] {
    catch { connect_bd_net $periph_rst [get_bd_pins $pin] }
}

puts "        Done."

# -----------------------------------------------------------------------
# STEP 5: Clear all existing address assignments
# -----------------------------------------------------------------------
puts ""
puts "Step 5: Clearing all address assignments..."
foreach space [get_bd_addr_spaces] {
    foreach seg [get_bd_addr_segs \
        -of_objects [get_bd_addr_spaces $space] -quiet] {
        catch { unassign_bd_address $seg }
    }
}
puts "        Done."

# -----------------------------------------------------------------------
# STEP 6: Assign addresses
# -----------------------------------------------------------------------
puts ""
puts "Step 6: Assigning addresses..."

# JTAG -> NPU CSR
assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs tinynpu_0/s_axi/reg0] \
    -range 64K -offset 0x40000000
puts "        JTAG -> NPU CSR      0x40000000"

# JTAG -> DMA CSR
assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] \
    -range 64K -offset 0x41E00000
puts "        JTAG -> DMA CSR      0x41E00000"

# JTAG -> VTC CSR
assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs vtc_0/ctrl/Reg] \
    -range 64K -offset 0x44A00000
puts "        JTAG -> VTC CSR      0x44A00000"

# JTAG -> BRAM (via csr_intercon M03 -> mem_intercon_1 S01 -> bram_ctrl_0)
assign_bd_address \
    -target_address_space /jtag_axi_0/Data \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        JTAG -> BRAM Port A  0xC0000000"

# DMA -> BRAM Port A
assign_bd_address \
    -target_address_space /axi_dma_0/Data_S2MM \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        DMA  -> BRAM Port A  0xC0000000"

# NPU -> BRAM Port B
assign_bd_address \
    -target_address_space /tinynpu_0/m_axi \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] \
    -range 8K -offset 0xC0000000
puts "        NPU  -> BRAM Port B  0xC0000000"

# -----------------------------------------------------------------------
# STEP 7: Validate and Save
# -----------------------------------------------------------------------
puts ""
puts "Step 7: Validating and saving..."
validate_bd_design
save_bd_design

puts ""
puts "======================================================="
puts " DONE! If validation passed, generate wrapper and"
puts " run Synthesis -> Implementation -> Bitstream."
puts "======================================================="
