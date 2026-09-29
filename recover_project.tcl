# recover_project.tcl
set project_name "npu200jb"
set project_dir "D:/Final year project/npu200jb"

# Create project, overwriting the corrupted .xpr
create_project ${project_name} ${project_dir} -part xc7z020clg400-1 -force

# Add existing IP repos
set_property ip_repo_paths [list \
    "D:/Final year project/Shared/IP/digilent-vivado-library" \
    "D:/Final year project/IP/TinyNPU200" \
] [current_project]
update_ip_catalog

# Add existing Block Design
add_files -norecurse [list "${project_dir}/npu200jb.srcs/sources_1/bd/npu_system/npu_system.bd"]
set wrapper_file "${project_dir}/npu200jb.gen/sources_1/bd/npu_system/hdl/npu_system_wrapper.v"
add_files -norecurse [list $wrapper_file]
update_compile_order -fileset sources_1
set_property top npu_system_wrapper [current_fileset]

# Try to find and add any existing XDC files
set xdc_files [glob -nocomplain "${project_dir}/npu200jb.srcs/constrs_1/**/*.xdc"]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
} else {
    # Fallback to shared pynq-z2.xdc if the local copy was lost
    add_files -fileset constrs_1 -norecurse [list "D:/Final year project/Shared/constraints/pynq-z2.xdc"]
}

puts "Project recovered successfully!"
