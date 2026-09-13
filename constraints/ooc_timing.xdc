# Out-of-Context (OOC) Timing Constraints for TinyNPU200
# Target Clock: 125 MHz (8.000 ns)

create_clock -name aclk -period 10.000 [get_ports aclk]

# Tell Vivado to treat this port as a global clock buffer in OOC mode
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports aclk]

# Force bbox_decoder to use LUTs instead of DSPs to save space
set_property USE_DSP no [get_cells -hier -filter {REF_NAME == bbox_decoder}]

