create_project -force ip_pkg "ip_pkg" -part xc7z020clg400-1
add_files -scan_for_includes "IP/TinyNPU200/src"
set_property top tinynpu_top [get_filesets sources_1]
update_compile_order -fileset sources_1
ipx::package_project -root_dir IP/TinyNPU200 -vendor HariharanGanesh -library user -taxonomy /UserIP -import_files -set_current false
ipx::unload_core IP/TinyNPU200/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory IP/TinyNPU200 IP/TinyNPU200/component.xml
update_compile_order -fileset sources_1
ipx::merge_project_changes files [ipx::current_core]
ipx::merge_project_changes hdl_parameters [ipx::current_core]
ipx::merge_project_changes ports [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
