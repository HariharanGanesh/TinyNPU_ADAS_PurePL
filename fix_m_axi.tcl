# Disconnect miswired m_axi and route to DDR memory
puts "================================================="
puts " FIXING MISWIRED NPU M_AXI AND RELAUNCHING"
puts "================================================="

open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *npu_system.bd]

# 1. Disconnect the miswired m_axi port
set bad_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins tinynpu_0/m_axi]]
if {$bad_net != ""} {
    delete_bd_objs $bad_net
}

# 2. Auto-route the NPU's AXI Master to the Zynq's HP0 (DDR Memory) port
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/tinynpu_0/m_axi} Slave {/ps7/S_AXI_HP0} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins tinynpu_0/m_axi]

# 3. Ensure addressing is correct
assign_bd_address -quiet [get_bd_addr_segs {ps7/S_AXI_HP0/HP0_DDR_LOWOCM}]

validate_bd_design
save_bd_design

set_property synth_checkpoint_mode None [get_files npu_system.bd]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "================================================="
puts " BITSTREAM RE-GENERATED SUCCESSFULLY!"
puts "================================================="
