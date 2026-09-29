catch { open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr }
update_ip_catalog -rebuild
catch { upgrade_ip [get_ips *dvi2rgb*] }

# 1. Generate the BD
set bd_file [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"]
generate_target all $bd_file -force

# 2. Make the wrapper and add it to the project explicitly
set wrapper_path [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_path

# 3. Force the top module
set_property top npu_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# 4. Configure aggressive Explore runs
reset_run synth_1
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]

set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# 5. Launch the build natively!
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1