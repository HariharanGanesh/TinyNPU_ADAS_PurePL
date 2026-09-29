open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
open_bd_design {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}
set clk_net [get_bd_nets -of_objects [get_bd_pins /clk_wiz_0/clk_out2]]
puts " Connected to clk_out2: [get_bd_pins -of_objects ]