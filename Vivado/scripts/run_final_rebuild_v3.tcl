## run_final_rebuild_v3.tcl
## Correct Vivado BD rebuild flow:
##   - Re-packages tinynpu100 IP (picks up clk_postproc fix in tinynpu_top.v)
##   - Uses generate_target to regenerate BD wrapper files (including frame_gen)
##   - Does NOT delete any IP directories (avoids missing file errors)
##   - Full rebuild with post-route phys_opt

cd "D:/Final year project"
set PROJ "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set BD   "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.srcs/sources_1/bd/tinynpu_system_bd/tinynpu_system_bd.bd"

## =======================================================
## STEP 1: Re-package tinynpu100 IP (picks up RTL changes)
## =======================================================
puts "=== STEP 1: Re-packaging tinynpu100 IP ==="
set IP_DIR "D:/ip_repo/tinynpu"
set PART   "xc7z020clg400-1"

set rtl_files [concat \
    [glob -nocomplain "rtl/activation/*.v"]   \
    [glob -nocomplain "rtl/axi/*.v"]          \
    [glob -nocomplain "rtl/buffers/*.v"]      \
    [glob -nocomplain "rtl/clocking/*.v"]     \
    [glob -nocomplain "rtl/control/*.v"]      \
    [glob -nocomplain "rtl/core/*.v"]         \
    [glob -nocomplain "rtl/dma/*.v"]          \
    [glob -nocomplain "rtl/dw_engine/*.v"]    \
    [glob -nocomplain "rtl/pe/*.v"]           \
    [glob -nocomplain "rtl/pooling/*.v"]      \
    [glob -nocomplain "rtl/quantization/*.v"] \
    [glob -nocomplain "rtl/systolic_array/*.v"] \
    [glob -nocomplain "rtl/top/*.v"]          \
]
puts "INFO: Found [llength $rtl_files] RTL files"

create_project -in_memory -part $PART -force
read_verilog $rtl_files
set_property top tinynpu_top [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $IP_DIR \
    -vendor "harih" -library "user" \
    -taxonomy "/UserIP" -import_files -force -quiet

set_property name         tinynpu100       [ipx::current_core]
set_property vendor        harih            [ipx::current_core]
set_property library       user             [ipx::current_core]
set_property version       1.0              [ipx::current_core]
set_property display_name "TinyNPU 100MHz" [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
puts "IP packaged to $IP_DIR"

## =======================================================
## STEP 2: Open project and configure
## =======================================================
puts "=== STEP 2: Configuring project ==="
open_project $PROJ

# Refresh IP repo
set_property ip_repo_paths "D:/ip_repo" [current_project]
update_ip_catalog -rebuild
puts "IP catalog updated"

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Open BD, set 100 MHz, save
open_bd_design $BD
set ps_cell [get_bd_cells -quiet processing_system7_0]
if {$ps_cell ne ""} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] $ps_cell
    validate_bd_design -quiet
    save_bd_design -quiet
    puts "PS clock = 100 MHz"
}

# Upgrade any locked IPs (picks up new tinynpu100 from ip_repo)
set locked_ips [get_ips -filter {IS_LOCKED==1}]
if {[llength $locked_ips] > 0} {
    upgrade_ip $locked_ips
    puts "Upgraded [llength $locked_ips] locked IP(s)"
}

## =======================================================
## STEP 3: Force regeneration of ALL BD wrapper files
##   This creates tinynpu_system_bd_frame_gen_0_0.v and
##   tinynpu_system_bd_tinynpu100_0_0.v BEFORE synthesis
## =======================================================
puts "=== STEP 3: Generating all BD target files ==="
set bd_file [get_files -of_objects [get_filesets sources_1] {*.bd}]
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet
puts "BD wrapper files regenerated"

## =======================================================
## STEP 4: Set impl strategy and rebuild
## =======================================================
puts "=== STEP 4: Launching rebuild ==="
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Build launched. Waiting (~35-45 min)..."
wait_on_run impl_1

## =======================================================
## STEP 5: Check timing
## =======================================================
puts "=== STEP 5: Checking timing ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts " Bitstream:"
    puts " .../impl_1/tinynpu_system_bd_wrapper.bit"
} else {
    puts " Final WNS = $wns ns -- check final_timing_summary.txt"
}
puts "=========================================================="
