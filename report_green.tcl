open_checkpoint IP/TinyNPU200/routed.dcp
create_clock -period 8.100 -name clk -waveform {0.000 4.050} [get_ports aclk]
report_utilization -hierarchical -file "util_fixed.rpt"
report_timing_summary -file "timing_fixed.rpt"
report_power -file "power_fixed.rpt"
