# Upgrade IP and reconnect the clocks
puts "================================================="
puts " UPGRADING IP AND RECONNECTING CLOCKS"
puts "================================================="

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

update_ip_catalog -rebuild
upgrade_ip [get_ips *tinynpu_0*] -log ip_upgrade.log

open_bd_design [get_files *npu_system.bd]

# Explicitly connect the newly renamed aclk and aresetn pins
connect_bd_net -quiet [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins tinynpu_0/aclk]
connect_bd_net -quiet [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins tinynpu_0/aresetn]

validate_bd_design
save_bd_design

set_property synth_checkpoint_mode None [get_files npu_system.bd]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "================================================="
puts " BITSTREAM RE-GENERATED SUCCESSFULLY!"
puts "================================================="
