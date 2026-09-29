open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set_property part xc7z020clg400-1 [current_project]

# Reset and delete all broken GUI runs
reset_runs synth_1
foreach run [get_runs -filter {IS_SYNTHESIS == 1 && NAME != "synth_1"}] {
    delete_runs $run
}

# Regenerate Block Design targets cleanly for the GUI
generate_target all [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -force
export_ip_user_files -of_objects [get_files RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd] -no_script -sync -force
create_ip_run [get_files -of_objects [get_fileset sources_1] RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd]

# Suppress the benign ILA duplicate warning
set_msg_config -id "[filemgmt 20-1318]" -suppress
set_msg_config -id "[HDL 9-3756]" -suppress

close_project