# =============================================================================
# TinyNPU200 Full PL - One-Click Vivado Project Builder
# Target Board: PYNQ-Z2 (xc7z020clg400-1)
# =============================================================================

set script_dir [file dirname [info script]]
set root_dir   [file normalize "$script_dir/.."]
set proj_dir   [file normalize "$root_dir/npu200_project"]
set repo_dir   [file normalize "$root_dir/ip_repo"]
set xdc_path   [file normalize "$root_dir/constraints/hdmi_pins.xdc"]
set hex_path   [file normalize "$root_dir/data/dummy_weights.hex"]

puts "======================================================="
puts " TinyNPU200 Full PL - Automated Vivado Project Builder"
puts " Target Part: xc7z020clg400-1 (PYNQ-Z2)"
puts "======================================================="

# Create Vivado Project
create_project npu200_project "$proj_dir" -part xc7z020clg400-1 -force

# Configure IP Repositories
set_property ip_repo_paths [list \
  "$repo_dir/NPU300PM" \
  "$repo_dir/digilent-vivado-library" \
] [current_project]
update_ip_catalog

# Add Constraints and Initial Hex Weights
add_files -fileset constrs_1 -norecurse "$xdc_path"
catch { add_files -norecurse "$hex_path" }

puts "\n[SUCCESS] Project created and IP catalog configured!"
puts "          To build bitstream, run: source {$script_dir/fix_all_errors.tcl}"
