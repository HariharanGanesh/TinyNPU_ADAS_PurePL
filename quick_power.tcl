read_verilog [glob IP/TinyNPU200/src/*.v]
synth_design -top tinynpu_top -part xc7z020clg400-1 -mode out_of_context
create_clock -period 8.100 -name clk -waveform {0.000 4.050} [get_ports aclk]
report_power -file "power_synth.rpt"
