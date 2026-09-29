open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

# Reconnect aclk
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins tinynpu_0/aclk]}

# Reconnect aresetn
# Let's try to connect it to proc_sys_reset_0's peripheral_aresetn
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins tinynpu_0/aresetn]}

save_bd_design
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips *tinynpu*] -no_script -sync -force -quiet

# Clean Synthesis run
reset_run synth_1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
launch_runs synth_1 -jobs 6
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
exit
