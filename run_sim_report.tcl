create_project -force sim_test "D:/Final year project/sim_test" -part xc7z020clg400-1
add_files -fileset sources_1 "D:/Final year project/IP/TinyNPU200/src"
add_files -fileset sim_1 "D:/Final year project/IP/TinyNPU200/sim/tb_tinynpu_top.sv"
add_files -fileset sim_1 "D:/Final year project/IP/TinyNPU200/sim/dummy_weights.hex"
set_property top tb_tinynpu_top [get_filesets sim_1]
launch_simulation
run 200 us
close_project
