# =============================================================================
# update_to_pl_frontend.tcl
# Updates BOTH Vivado projects to use PL-direct data path:
#   frame_gen → tinynpu_top → result_capture  (no DMA in stream path)
#   DMA remains for weight/config memory access only
#
# Run in Vivado Tcl Console:
#   source {d:/Final year project/update_to_pl_frontend.tcl}
# =============================================================================

set ROOT_DIR "D:/Final year project"
set RTL_DIR  "$ROOT_DIR/rtl"
set FE_DIR   "$ROOT_DIR/rtl/frontend"

set PYNQ_PROJ "$ROOT_DIR/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set NPU2K_PROJ "$ROOT_DIR/tinyNPU2k/tinyNPU2k.xpr"

# =============================================================================
# Proc: update_project
# =============================================================================
proc update_project {proj_path bd_name npu_cell_name} {
    global FE_DIR

    puts "\n============================================================"
    puts " Updating: $proj_path"
    puts "============================================================"

    # -------------------------------------------------------------------------
    # 1. Open project (skip if already open)
    # -------------------------------------------------------------------------
    set proj_name [file rootname [file tail $proj_path]]
    if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
        open_project "$proj_path"
    } else {
        puts "  INFO: Project already open — skipping open_project"
    }
    update_compile_order -fileset sources_1 -quiet

    # -------------------------------------------------------------------------
    # 2. Add new PL frontend RTL files
    # -------------------------------------------------------------------------
    puts "\n--- Adding PL Frontend RTL sources ---"
    set fe_files [list \
        "$FE_DIR/frame_gen.v" \
        "$FE_DIR/result_capture.v" \
        "$FE_DIR/pl_top.v" \
    ]
    foreach f $fe_files {
        if {[file exists $f]} {
            add_files -norecurse [list $f]
            puts "  Added: [file tail $f]"
        } else {
            puts "  WARNING: File not found: $f"
        }
    }
    update_compile_order -fileset sources_1

    # -------------------------------------------------------------------------
    # 3. Open existing Block Design
    # -------------------------------------------------------------------------
    puts "\n--- Opening Block Design: $bd_name ---"
    set bd_file [get_files -quiet "${bd_name}.bd"]
    if {$bd_file eq ""} {
        puts "ERROR: Block design $bd_name not found."
        return
    }
    open_bd_design $bd_file

    # -------------------------------------------------------------------------
    # 4. Disconnect DMA from NPU AXI-Stream paths
    #    (keep DMA for AXI memory access — weight loading)
    # -------------------------------------------------------------------------
    puts "\n--- Disconnecting DMA from NPU stream path ---"

    # Disconnect MM2S → NPU s_axis
    set mm2s_net [get_bd_intf_nets -of_objects [get_bd_intf_pins ${npu_cell_name}/s_axis] -quiet]
    if {$mm2s_net ne ""} {
        delete_bd_objs $mm2s_net
        puts "  Removed: DMA→NPU s_axis net"
    }

    # Disconnect NPU m_axis → DMA S2MM
    set s2mm_net [get_bd_intf_nets -of_objects [get_bd_intf_pins ${npu_cell_name}/m_axis] -quiet]
    if {$s2mm_net ne ""} {
        delete_bd_objs $s2mm_net
        puts "  Removed: NPU→DMA m_axis net"
    }

    # Also remove DMA S_AXIS_S2MM if now unconnected (optional cleanup)

    # -------------------------------------------------------------------------
    # 5. Add frame_gen as Module Reference
    # -------------------------------------------------------------------------
    puts "\n--- Adding frame_gen module to BD ---"
    startgroup
    set fg [create_bd_cell -type module -reference frame_gen frame_gen_0]
    set_property -dict [list \
        CONFIG.IMG_WIDTH  {160} \
        CONFIG.IMG_HEIGHT {160} \
        CONFIG.CHANNELS   {1}   \
        CONFIG.BAR_WIDTH  {16}  \
        CONFIG.BAR_SPEED  {2}   \
    ] $fg
    endgroup
    puts "  Created: frame_gen_0"

    # -------------------------------------------------------------------------
    # 6. Add result_capture as Module Reference
    # -------------------------------------------------------------------------
    puts "\n--- Adding result_capture module to BD ---"
    startgroup
    set rc [create_bd_cell -type module -reference result_capture result_capture_0]
    endgroup
    puts "  Created: result_capture_0"

    # -------------------------------------------------------------------------
    # 7. Connect frame_gen clock and reset
    # -------------------------------------------------------------------------
    puts "\n--- Connecting frame_gen clocks and resets ---"

    # Get PS clock pin (works for both ps7 and processing_system7_0 naming)
    set clk_pin [get_bd_pins -quiet ps7/FCLK_CLK0]
    if {$clk_pin eq ""} { set clk_pin [get_bd_pins -quiet processing_system7_0/FCLK_CLK0] }
    if {$clk_pin eq ""} { puts "WARNING: Cannot find PS FCLK_CLK0" }

    # Get reset pin
    set rst_pin [get_bd_pins -quiet ps7/FCLK_RESET0_N]
    if {$rst_pin eq ""} { set rst_pin [get_bd_pins -quiet processing_system7_0/FCLK_RESET0_N] }

    # Connect clock to frame_gen and result_capture
    if {$clk_pin ne ""} {
        connect_bd_net $clk_pin \
            [get_bd_pins frame_gen_0/clk] \
            [get_bd_pins result_capture_0/clk]
        puts "  Connected: FCLK_CLK0 → frame_gen_0/clk, result_capture_0/clk"
    }

    # Connect reset
    if {$rst_pin ne ""} {
        connect_bd_net $rst_pin \
            [get_bd_pins frame_gen_0/rst_n] \
            [get_bd_pins result_capture_0/rst_n]
        puts "  Connected: FCLK_RESET0_N → rst_n"
    }

    # -------------------------------------------------------------------------
    # 8. Connect frame_gen → NPU s_axis (AXI-Stream)
    # -------------------------------------------------------------------------
    puts "\n--- Connecting frame_gen → NPU s_axis ---"
    connect_bd_intf_net \
        [get_bd_intf_pins frame_gen_0/m_axis] \
        [get_bd_intf_pins ${npu_cell_name}/s_axis]
    puts "  Connected: frame_gen_0/m_axis → ${npu_cell_name}/s_axis"

    # -------------------------------------------------------------------------
    # 9. Connect NPU m_axis → result_capture s_axis
    # -------------------------------------------------------------------------
    puts "\n--- Connecting NPU m_axis → result_capture ---"
    connect_bd_intf_net \
        [get_bd_intf_pins ${npu_cell_name}/m_axis] \
        [get_bd_intf_pins result_capture_0/s_axis]
    puts "  Connected: ${npu_cell_name}/m_axis → result_capture_0/s_axis"

    # -------------------------------------------------------------------------
    # 10. Make frame_gen control pins external (PS can drive via GPIO)
    # -------------------------------------------------------------------------
    puts "\n--- Making frame_gen control ports external ---"
    make_bd_pins_external [get_bd_pins frame_gen_0/enable]
    make_bd_pins_external [get_bd_pins frame_gen_0/single_shot]
    make_bd_pins_external [get_bd_pins frame_gen_0/frame_count]
    make_bd_pins_external [get_bd_pins frame_gen_0/frame_done]

    # Make result_capture outputs external (readable by PS)
    make_bd_pins_external [get_bd_pins result_capture_0/det_bbox_x]
    make_bd_pins_external [get_bd_pins result_capture_0/det_bbox_y]
    make_bd_pins_external [get_bd_pins result_capture_0/det_bbox_w]
    make_bd_pins_external [get_bd_pins result_capture_0/det_bbox_h]
    make_bd_pins_external [get_bd_pins result_capture_0/det_confidence]
    make_bd_pins_external [get_bd_pins result_capture_0/det_valid]
    puts "  Made external: frame_gen controls, result_capture outputs"

    # -------------------------------------------------------------------------
    # 11. Validate, save, regenerate wrapper
    # -------------------------------------------------------------------------
    puts "\n--- Validating Block Design ---"
    assign_bd_address -quiet
    validate_bd_design

    save_bd_design
    puts "  Block design saved."

    # Regenerate wrapper
    make_wrapper -files [get_files "${bd_name}.bd"] -top -force
    set wrapper [lindex [glob -nocomplain \
        "[file dirname [file dirname $bd_file]]/hdl/${bd_name}_wrapper.v" \
        "[get_property DIRECTORY [current_project]]/*.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v"] 0]

    if {$wrapper ne ""} {
        # Remove old wrapper, add new
        remove_files -fileset sources_1 [get_files -quiet "*${bd_name}_wrapper.v"] -quiet
        add_files -norecurse [list $wrapper]
        set_property top ${bd_name}_wrapper [current_fileset]
        puts "  Wrapper updated: $wrapper"
    }

    update_compile_order -fileset sources_1

    puts "\n✅ Project updated: [current_project]"
    puts "   New data path: frame_gen_0 → ${npu_cell_name} → result_capture_0"
    puts "   DMA: remains connected for AXI memory (weight access) only"
    puts "\n   To rebuild bitstream:"
    puts "   reset_run synth_1 ; launch_runs impl_1 -to_step write_bitstream -jobs 4"
}

# =============================================================================
# Run updates on both projects
# =============================================================================

# --- 1. Update tinynpu_pynq_system ---
if {[file exists $PYNQ_PROJ]} {
    update_project $PYNQ_PROJ "tinynpu_system_bd" "tinynpu100_0"
} else {
    puts "WARNING: tinynpu_pynq_system project not found at $PYNQ_PROJ"
}

# --- 2. Update tinyNPU2k ---
# tinyNPU2k was created but BD may be empty or have 'npu' cell name
# We check what exists and only update if BD has the NPU cell
if {[file exists $NPU2K_PROJ]} {
    open_project $NPU2K_PROJ
    set npu2k_bd [get_files -quiet "tinyNPU2k_bd.bd"]
    if {$npu2k_bd ne ""} {
        open_bd_design $npu2k_bd
        # Auto-detect NPU cell name
        set npu_cells [get_bd_cells -quiet -filter {VLNV =~ "*tinynpu*"} ]
        if {[llength $npu_cells] > 0} {
            set npu_cell_name [lindex $npu_cells 0]
            puts "Found NPU cell in tinyNPU2k: $npu_cell_name"
            close_bd_design $npu2k_bd
            update_project $NPU2K_PROJ "tinyNPU2k_bd" $npu_cell_name
        } else {
            puts "INFO: tinyNPU2k BD has no NPU cell yet — skipping BD update"
            puts "      Adding RTL files only..."
            foreach f [list \
                "$FE_DIR/frame_gen.v" \
                "$FE_DIR/result_capture.v" \
                "$FE_DIR/pl_top.v"] {
                if {[file exists $f]} {
                    add_files -norecurse [list $f]
                    puts "  Added: [file tail $f]"
                }
            }
            update_compile_order -fileset sources_1
            save_project
            puts "✅ tinyNPU2k: RTL sources added (BD update deferred)"
        }
    } else {
        puts "INFO: tinyNPU2k has no BD yet — adding RTL files only"
    }
} else {
    puts "WARNING: tinyNPU2k project not found at $NPU2K_PROJ"
}

puts "\n============================================================"
puts " BOTH PROJECTS UPDATED"
puts " PL-direct data path active — no PS/DMA in inference loop"
puts "============================================================"
