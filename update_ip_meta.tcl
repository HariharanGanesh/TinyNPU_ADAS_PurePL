open_project "D:/Final year project/tinynpu200_ip_packager/tinynpu200_ip_packager.xpr"
ipx::open_core "D:/Final year project/IP/TinyNPU200/component.xml"
ipx::merge_project_changes files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
