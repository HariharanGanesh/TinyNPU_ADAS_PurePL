open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
open_bd_design {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}
set net200 [get_bd_nets -of_objects [get_bd_pins clk_wiz_0/clk_out2]]
set pins [get_bd_pins -of_objects $net200]
set f [open "pin_dump.txt" w]
foreach pin $pins {
    puts $f $pin
}
close $f
