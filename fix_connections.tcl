open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files npu_system.bd]

# The NPU has an AXI Lite port. If we run connection automation, it will wire clocks/resets automatically for the whole IP if they are associated.
# Wait, let's just manually connect them to the same net that feeds the AXI interconnect.
set clk_net [get_bd_nets -of_objects [get_bd_pins clk_wiz_0/clk_out1]]
set rst_net [get_bd_nets -of_objects [get_bd_pins proc_sys_reset_0/peripheral_aresetn]]

connect_bd_net -net $clk_net [get_bd_pins tinynpu_0/aclk]
connect_bd_net -net $rst_net [get_bd_pins tinynpu_0/aresetn]

validate_bd_design
save_bd_design