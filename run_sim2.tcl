create_project -force test_sim "test_sim" -part xc7z020clg400-1
add_files -scan_for_includes "IP/TinyNPU200/src"
add_files -fileset sim_1 "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
set_property top tb_tinynpu_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation
run all
close_project
