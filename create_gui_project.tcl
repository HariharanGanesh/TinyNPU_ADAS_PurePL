create_project TinyNPU200_Project "D:/Final year project/TinyNPU200_Project" -part xc7z020clg400-1 -force

# Add RTL sources
add_files "D:/Final year project/IP/TinyNPU200/src"

# Add Simulation sources
add_files -fileset sim_1 "D:/Final year project/IP/TinyNPU200/sim"

# Add OOC Constraint (for timing closure)
add_files -fileset constrs_1 "D:/Final year project/IP/TinyNPU200/ooc_timing.xdc"
set_property USED_IN {synthesis implementation} [get_files "D:/Final year project/IP/TinyNPU200/ooc_timing.xdc"]

# Configure for Out-of-Context synthesis (since it's an IP)
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Apply the strict Explore directives we used to hit 123 MHz
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# Set Top Modules
set_property top tinynpu_top [current_fileset]
set_property top tb_tinynpu_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

close_project
