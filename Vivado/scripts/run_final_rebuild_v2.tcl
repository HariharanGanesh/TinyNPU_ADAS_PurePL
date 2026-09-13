## run_final_rebuild_v2.tcl
## Fixed rebuild flow:
##   1. Re-package tinynpu IP (picks up threshold_filter clk_postproc fix)
##   2. Update IP catalog in block design
##   3. Only delete frame_gen cache (module_ref - safe to delete)
##   4. Full rebuild with post-route phys_opt
## =========================================================================

set PROJ "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"

## ----- STEP 1: Re-package tinynpu100 IP from updated RTL -----
puts "=== STEP 1: Re-packaging tinynpu100 IP with updated RTL ==="
cd "D:/Final year project"

set IP_DIR "D:/ip_repo/tinynpu"
set PART "xc7z020clg400-1"

# Collect all RTL files
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

# Create in-memory project for IP packaging
create_project -in_memory -part $PART -force
read_verilog $rtl_files
set_property top tinynpu_top [current_fileset]
update_compile_order -fileset sources_1

# Re-package (overwrites existing IP in ip_repo)
ipx::package_project -root_dir $IP_DIR \
    -vendor "harih" -library "user" \
    -taxonomy "/UserIP" -import_files -force \
    -quiet

set_property name         tinynpu100       [ipx::current_core]
set_property vendor        harih            [ipx::current_core]
set_property library       user             [ipx::current_core]
set_property version       1.0              [ipx::current_core]
set_property display_name "TinyNPU 100MHz" [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
puts "IP packaged to $IP_DIR"

## ----- STEP 2: Open main project and update IP -----
puts "=== STEP 2: Opening project and updating IP catalog ==="
open_project $PROJ

# Refresh IP repo so Vivado sees new tinynpu100
set_property ip_repo_paths "D:/ip_repo" [current_project]
update_ip_catalog -rebuild

# Disable problematic XDC
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "Disabled tinynpu.xdc"
}

# Open BD and set 100 MHz clock
open_bd_design {D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.srcs/sources_1/bd/tinynpu_system_bd/tinynpu_system_bd.bd}

set ps_cell [get_bd_cells -quiet processing_system7_0]
if {$ps_cell ne ""} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] $ps_cell
    validate_bd_design -quiet
    save_bd_design -quiet
    puts "PS clock = 100 MHz"
}

# Upgrade locked tinynpu100 IP to pick up new packaged version
set locked_ips [get_ips -filter {IS_LOCKED==1}]
if {[llength $locked_ips] > 0} {
    upgrade_ip $locked_ips
    puts "Upgraded [llength $locked_ips] locked IP(s)"
}

## ----- STEP 3: Only delete frame_gen cache (safe - it's a module_ref) -----
puts "=== STEP 3: Clearing frame_gen cache only ==="
set gen_dir "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.gen/sources_1/bd/tinynpu_system_bd/ip"
file delete -force "$gen_dir/tinynpu_system_bd_frame_gen_0_0"
puts "Cleared frame_gen cache"

## ----- STEP 4: Build with best timing strategy -----
puts "=== STEP 4: Launching full rebuild ==="
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Build launched. Waiting (~35-45 min)..."
wait_on_run impl_1

## ----- STEP 5: Report results -----
puts "=== STEP 5: Checking timing results ==="
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]]
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"

puts ""
puts "=========================================================="
if {$wns >= 0.0} {
    puts " SUCCESS! Timing CLOSED at 100 MHz! WNS = $wns ns"
    puts " Bitstream ready at:"
    puts " D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.runs/impl_1/tinynpu_system_bd_wrapper.bit"
} else {
    puts " Final WNS = $wns ns -- check final_timing_summary.txt"
}
puts "=========================================================="
