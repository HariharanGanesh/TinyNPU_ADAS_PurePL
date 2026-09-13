# False path for asynchronous HDMI lock status crossing to 125 MHz NPU domain
set_false_path -from [get_clocks clk_fpga_1] -to [get_clocks clk_fpga_0]
