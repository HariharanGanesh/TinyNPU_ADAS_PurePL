# 1. Update the IP Core
ipx::open_core "D:/Final year project/IP/NPU300PM/component.xml"

# Force Vivado to re-scan the src/ folder and update ports
set_property core_revision [expr [get_property core_revision [ipx::current_core]] + 1] [ipx::current_core]
ipx::merge_project_changes ports [ipx::current_core]
ipx::merge_project_changes hdl_parameters [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

puts "IP Core ports and checksums successfully updated!"
