# fix_project.tcl
puts "================================================="
puts " Antigravity Auto-Fix Script Started (v3)"
puts "================================================="

# 1. Remove all currently missing files (the broken links)
set missing_files [get_files -filter {IS_AVAILABLE == 0}]
if {[llength $missing_files] > 0} {
    puts "Removing broken file links..."
    remove_files $missing_files
}

# 2. Add the correct source directory safely (using cd to avoid the spaces bug)
puts "Adding correct source files..."
set orig_dir [pwd]
cd "D:/Final year project/IP/TinyNPU200/src"
add_files -fileset sources_1 [glob *.v]
cd $orig_dir

# 3. Add the simulation testbench safely
puts "Adding simulation testbench..."
cd "D:/Final year project/IP/TinyNPU200/sim"
add_files -fileset sim_1 tb_tinynpu_top.sv
cd $orig_dir

# 4. Set the top modules
set_property top tinynpu_top [get_filesets sources_1]
set_property top tb_tinynpu_top [get_filesets sim_1]

# 5. Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 6. Fix IP Packager parameters
puts "Updating IP Packager..."
set core [ipx::current_core]

set_property display_name {TinyNPU} $core
set_property description {High-performance INT8 Neural Processing Unit for Edge Devices} $core

ipx::merge_project_changes files $core
ipx::save_core $core

puts "================================================="
puts " Project fixed, Simulation ready, and IP Packaged! "
puts "================================================="
