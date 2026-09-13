# Bypass BUFG-BUFG cascade placement error for PS7 FCLK_CLK0 to TinyNPU Clock Gating BUFGCE cells
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets npu_system_i/ps7/inst/FCLK_CLK0]
