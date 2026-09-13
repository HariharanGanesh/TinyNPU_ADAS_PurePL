set proj_path "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set proj_name [file rootname [file tail $proj_path]]
if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
    open_project "$proj_path"
}

open_bd_design {D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.srcs/sources_1/bd/tinynpu_system_bd/tinynpu_system_bd.bd}

puts "--- Reducing PS Clock Frequency to 50 MHz to meet timing ---"

# The Zynq PS block is typically named processing_system7_0
set ps_cell [get_bd_cells -quiet processing_system7_0]
if {$ps_cell eq ""} {
    set ps_cell [get_bd_cells -quiet ps7]
}

if {$ps_cell ne ""} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {50}] $ps_cell
    puts "Set $ps_cell FCLK_CLK0 to 50 MHz"
} else {
    puts "WARNING: Could not find Zynq PS cell to change frequency."
}

validate_bd_design
save_bd_design
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "INFO: Build finished! Check timing summary now."
