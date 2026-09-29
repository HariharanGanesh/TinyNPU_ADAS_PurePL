catch { open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr }

set bd_file [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"]
make_wrapper -files $bd_file -top
add_files -norecurse RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.gen/sources_1/bd/npu_system/hdl/npu_system_wrapper.v

set_property top npu_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]

set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1