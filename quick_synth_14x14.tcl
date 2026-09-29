read_verilog [glob IP/TinyNPU200/src/*.v]
synth_design -top tinynpu_top -part xc7z020clg400-1 -mode out_of_context
report_utilization -hierarchical -file "util_14x14.rpt"
