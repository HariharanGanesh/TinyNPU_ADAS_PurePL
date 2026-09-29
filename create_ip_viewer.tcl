create_project -force tinynpu_ip_viewer {D:/Final year project/tinynpu_ip_viewer} -part xc7z020clg400-1
read_verilog [glob "D:/Final year project/IP/NPU300PM/src/*.v"]
set_property top tinynpu_top [current_fileset]
update_compile_order -fileset sources_1
start_gui
