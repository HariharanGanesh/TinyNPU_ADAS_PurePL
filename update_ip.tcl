# 1. Update the IP Core (NO active project to prevent circular merging)
ipx::open_core "D:/Final year project/IP/NPU300PM/component.xml"

# Force Vivado to re-scan the src/ folder
set_property core_revision [expr [get_property core_revision [ipx::current_core]] + 1] [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

puts "IP Core successfully updated!"
