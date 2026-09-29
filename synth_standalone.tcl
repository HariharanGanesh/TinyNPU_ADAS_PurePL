create_project -in_memory -part xc7z020clg400-1
read_verilog [glob "D:/Final year project/IP/TinyNPU200/src/*.v"]
synth_design -top tinynpu_top -part xc7z020clg400-1 -mode out_of_context

# Create a 125 MHz clock (8ns period)
create_clock -period 8.000 -name clk -waveform {0.000 4.000} [get_ports aclk]

# Run physical optimization to help with fanout and timing
opt_design
phys_opt_design -directive AggressiveExplore

report_utilization -hierarchical -file "util_fixed.rpt"
report_timing_summary -file "timing_fixed.rpt"
exit
