read_verilog [glob IP/TinyNPU200/src/*.v]
synth_design -top tinynpu_top -part xc7z020clg400-1 -mode out_of_context
create_clock -period 8.100 -name clk -waveform {0.000 4.050} [get_ports aclk]
opt_design -directive Explore
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
report_timing_summary -file "timing_14x14_post_route.rpt"
report_utilization -hierarchical -file "util_14x14_post_route.rpt"
report_power -file "power_14x14_post_route.rpt"
write_checkpoint -force "IP/TinyNPU200/routed_14x14.dcp"
