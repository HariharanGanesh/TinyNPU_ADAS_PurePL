open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

puts "--- 1. Fixing HDMI Reference Clock (200 MHz) ---"
set_property -dict [list CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} CONFIG.CLKOUT2_USED {true}] [get_bd_cells clk_wiz_0]
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins rgb2dvi_0/RefClk]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins dvi2rgb_0/RefClk]}

puts "--- 2. Mapping VTC Address ---"
source "D:/Final year project/fix_bd_addresses.tcl"

puts "--- 3. Synchronizing Resets ---"
source "D:/Final year project/fix_reset_auto.tcl"

puts "--- 4. Updating Constraints ---"
# Add new constraint file
add_files -fileset constrs_1 -norecurse "D:/Final year project/pynq_z2_customized.xdc"
# Remove old conflicting constraint files if they exist in the project
catch {remove_files -fileset constrs_1 "D:/Final year project/Versions/TinyNPU200J/constraints/hdmi_pins.xdc"}
catch {remove_files -fileset constrs_1 "D:/Final year project/pynq_z2_adas.xdc"}

puts "--- 5. Adding HPD ports to BD ---"
# Check if ports already exist
set rx_hpd_port [get_bd_ports rx_hpd -quiet]
if {$rx_hpd_port eq ""} {
    create_bd_port -dir O rx_hpd
    # Tie RX HPD high (1)
    connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_ports rx_hpd]
}
set tx_hpd_port [get_bd_ports tx_hpd -quiet]
if {$tx_hpd_port eq ""} {
    create_bd_port -dir I tx_hpd
    # Connect TX HPD to rgb2dvi_0/vid_pHPD if it exists, otherwise just leave it unconnected (it's constrained)
    catch {connect_bd_net [get_bd_ports tx_hpd] [get_bd_pins rgb2dvi_0/vid_pHPD]}
}

save_bd_design
puts "--- Done applying changes! Regenerating targets and launching implementation ---"
reset_target all [get_files *.bd]
generate_target all [get_files *.bd]

reset_run synth_1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "--- ALL TASKS COMPLETE ---"
exit
