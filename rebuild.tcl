open_project "D:/Final year project/npu200jb/npu200jb.xpr"
open_bd_design "D:/Final year project/npu200jb/npu200jb.srcs/sources_1/bd/npu_system/npu_system.bd"

# Add constraints if they don't exist
add_files -fileset constrs_1 -norecurse [list "D:/Final year project/Versions/TinyNPU200J/constraints/hdmi_pins.xdc"]

# Add our newly created explicit multiplier module so synthesis can find it (bypassing the IP packager cache)
add_files -norecurse [list "D:/Final year project/IP/TinyNPU200/src/pipelined_mult_8x8.v"]

# Restore the NPU clock to 125 MHz since we have fully pipelined the fabric multipliers in RTL!
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125.000000}] [get_bd_cells ps7]

# Add Fully Registered Slices (4) to the AXI Interconnect to break up the 7.154ns routing delay
set_property -dict [list CONFIG.S00_HAS_REGSLICE {4} CONFIG.M00_HAS_REGSLICE {4}] [get_bd_cells axi_mem_intercon]

# Set Implementation Strategy to Performance_Explore to force Vivado to tightly pack the fabric multipliers and resolve the final 6.1ns routing delay
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# Re-run synthesis and implementation
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
exit
