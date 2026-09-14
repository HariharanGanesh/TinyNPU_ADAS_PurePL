# ==============================================================================
# TinyNPU200 - IP Packager Script
# ==============================================================================

set project_name "tinynpu200_ip_packager"
set project_dir "./${project_name}"
set ip_repo_path "IP/TinyNPU200"

# 1. Create a temporary Vivado project
create_project -force $project_name $project_dir -part xc7z020clg400-1

# 2. Add all RTL source files (except the HDMI top-level test wrapper)
# We want `tinynpu_top` as the IP's top module.
add_files "Versions/TinyNPU200J/rtl/src/activation"
add_files "Versions/TinyNPU200J/rtl/src/axi"
add_files "Versions/TinyNPU200J/rtl/src/buffers"
add_files "Versions/TinyNPU200J/rtl/src/clocking"
add_files "Versions/TinyNPU200J/rtl/src/control"
add_files "Versions/TinyNPU200J/rtl/src/core"
add_files "Versions/TinyNPU200J/rtl/src/dma"
add_files "Versions/TinyNPU200J/rtl/src/dw_engine"
add_files "Versions/TinyNPU200J/rtl/src/frontend"
add_files "Versions/TinyNPU200J/rtl/src/osd"
add_files "Versions/TinyNPU200J/rtl/src/pe"
add_files "Versions/TinyNPU200J/rtl/src/pooling"
add_files "Versions/TinyNPU200J/rtl/src/quantization"
add_files "Versions/TinyNPU200J/rtl/src/systolic_array"
add_files "Versions/TinyNPU200J/rtl/src/top/tinynpu_top.v"

set_property top tinynpu_top [current_fileset]
update_compile_order -fileset sources_1

# 3. Package the project into an IP
ipx::package_project -root_dir $ip_repo_path -vendor {ai.local} -library {user} -taxonomy {/UserIP} -import_files -set_current false
ipx::unload_core "${ip_repo_path}/component.xml"
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $ip_repo_path "${ip_repo_path}/component.xml"

# 4. Finalize IP properties
set_property core_revision 2 [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::move_temp_component_back -component [ipx::current_core]

# 5. Cleanup temporary project
close_project -delete
puts "SUCCESS: TinyNPU200 IP Packaged to ${ip_repo_path}"
