# =============================================================================
# fix_reset_auto.tcl
# Connects proc_sys_reset_0/ext_reset_in to clk_wiz_0/locked so the design
# automatically comes out of reset as soon as the PLL clock stabilizes.
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Auto Power-On Reset Fix"
puts "======================================================="

open_bd_design {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}

# 1. Remove sys_rst_n external port if connected to ext_reset_in
catch { delete_bd_objs [get_bd_nets sys_rst_n_1] }
catch { delete_bd_objs [get_bd_ports sys_rst_n] }

# 2. Configure proc_sys_reset_0 to accept ACTIVE_HIGH reset (clk_wiz_0/locked is active high)
# When locked = 0 (clock unstable) -> system in reset
# When locked = 1 (clock stable)   -> reset released!
set_property CONFIG.RESET_BOARD_INTERFACE {Custom} [get_bd_cells proc_sys_reset_0]

# Connect clk_wiz_0/locked -> proc_sys_reset_0/ext_reset_in
catch {
    connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/ext_reset_in]
    puts "Connected: clk_wiz_0/locked -> proc_sys_reset_0/ext_reset_in"
}

# 3. Validate & Save
puts "Validating block design..."
validate_bd_design
save_bd_design
puts "Block design saved."

# 4. Generate Wrapper
make_wrapper -files [get_files {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}] -top
puts ""
puts "======================================================="
puts " SUCCESS! Block design updated with Auto-Reset."
puts " Now click 'Generate Bitstream' in Vivado!"
puts "======================================================="
