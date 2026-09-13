open_project npu200jpmax/npu200jpmax.xpr
open_bd_design npu200jpmax/npu200jpmax.srcs/sources_1/bd/npu_system/npu_system.bd
foreach pin [get_bd_pins -filter {TYPE == clk}] {
    puts "[get_property NAME $pin] : [get_property CONFIG.FREQ_HZ $pin]"
}