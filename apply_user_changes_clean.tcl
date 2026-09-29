cd "D:/Final year project"
open_project "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

puts "--- 1. Fixing HDMI Reference Clock (200 MHz) ---"
set_property -dict [list CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} CONFIG.CLKOUT2_USED {true}] [get_bd_cells clk_wiz_0]

puts "--- 2. Mapping VTC Address ---"
catch {assign_bd_address -target_address_space /riscv_adas_0/M_AXI [get_bd_addr_segs vtc/ctrl/Reg]}
catch {set_property offset 0x44A00000 [get_bd_addr_segs -of_objects [get_bd_cells vtc]]}

puts "--- 3. Synchronizing Resets ---"
set rst_net [get_bd_nets -of_objects [get_bd_pins proc_sys_reset_0/peripheral_aresetn]]
if {$rst_net ne ""} {
    catch {connect_bd_net -net $rst_net [get_bd_pins vtc/s_axi_aresetn]}
    catch {connect_bd_net -net $rst_net [get_bd_pins vid_in/aresetn]}
    catch {connect_bd_net -net $rst_net [get_bd_pins vid_out/aresetn]}
    catch {connect_bd_net -net $rst_net [get_bd_pins dvi2rgb_0/aRst_n]}
    catch {connect_bd_net -net $rst_net [get_bd_pins rgb2dvi_0/aRst_n]}
}

puts "--- 4. Updating Constraints ---"
add_files -fileset constrs_1 -norecurse "pynq_z2_customized.xdc"
catch {remove_files -fileset constrs_1 "Versions/TinyNPU200J/constraints/hdmi_pins.xdc"}
catch {remove_files -fileset constrs_1 "pynq_z2_adas.xdc"}

puts "--- 5. Adding HPD ports to BD ---"
set rx_hpd_port [get_bd_ports rx_hpd -quiet]
if {$rx_hpd_port eq ""} {
    create_bd_port -dir O rx_hpd
    catch {connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_ports rx_hpd]}
}
set tx_hpd_port [get_bd_ports tx_hpd -quiet]
if {$tx_hpd_port eq ""} {
    create_bd_port -dir I tx_hpd
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
