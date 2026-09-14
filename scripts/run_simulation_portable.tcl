# =============================================================================
# run_simulation_portable.tcl
# TinyNPU200 IP Core -- Portable Simulation Script
# Copyright (c) 2026 Hariharan Ganesh. All rights reserved.
# =============================================================================
# This script auto-detects the project location from its own path.
# Unlike run_all.tcl (hardcoded path), this works on any machine provided
# the repository directory structure is preserved.
#
# Usage:
#   vivado -mode batch -source scripts/run_simulation_portable.tcl
# =============================================================================

set script_dir  [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set xpr_path    [file join $project_root "tinynpu200_ip_packager" "tinynpu200_ip_packager.xpr"]

puts "INFO: Project root : $project_root"
puts "INFO: XPR path     : $xpr_path"

if {![file exists $xpr_path]} {
    puts "ERROR: Cannot find Vivado project at: $xpr_path"
    puts "ERROR: Ensure the repository structure is intact and"
    puts "ERROR: tinynpu200_ip_packager/ exists relative to scripts/"
    exit 1
}

open_project $xpr_path
reset_simulation -simset sim_1 -mode behavioral
launch_simulation
run all
close_project

puts "INFO: Simulation complete."
