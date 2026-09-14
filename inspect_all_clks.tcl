open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
open_bd_design {D:/Final year project/npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd}
set f [open "all_pins_dump.txt" w]
foreach clk_pin [get_bd_pins -of [get_bd_cells clk_wiz_0] -filter {TYPE == clk}] {
    puts $f "\n-------------------------------"
    puts $f "Clock Pin: $clk_pin"
    set net [get_bd_nets -quiet -of_objects $clk_pin]
    if {$net != ""} {
        puts $f " Net: $net"
        set conn_pins [get_bd_pins -quiet -of_objects $net]
        foreach cpin $conn_pins {
            puts $f "   -> $cpin"
        }
    } else {
        puts $f " (No net connected)"
    }
}
close $f
