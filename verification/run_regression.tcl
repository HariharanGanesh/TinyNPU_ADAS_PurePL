# =============================================================================
# run_regression.tcl
# TinyNPU200A Full Verification Regression Suite
# Run from Vivado TCL Console:
#   cd {D:/Final year project}
#   source verification/run_regression.tcl
# =============================================================================

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RTL_DIR   [file join \ IP/TinyNPU200/src]
set VERIF_DIR [file join \ verification/tb]
set LOG_DIR   [file join \ verification/regression_logs]
file mkdir \

# --------------------------------------------------------------------------
# RTL source list - compile order matters (dependencies first)
# --------------------------------------------------------------------------
set RTL_SOURCES {
    activation_buffer.v
    activation_unit.v
    axi4_lite_slave.v
    axis_sink.v
    axis_source.v
    bbox_decoder.v
    dma_controller.v
    dw_line_buffer.v
    hardswish_lut.v
    npu_controller.v
    output_buffer.v
    piecewise_sigmoid.v
    pipelined_mult_8x8.v
    pooling_unit.v
    processing_element.v
    requantization_unit.v
    systolic_array.v
    threshold_filter.v
    tinynpu_icg.v
    weight_buffer.v
    tinynpu_top.v
}

# --------------------------------------------------------------------------
# Testbench list: {top_module  tb_filename  timeout_ns}
# --------------------------------------------------------------------------
set TB_LIST {
    {tb_processing_element  tb_processing_element.sv  200000}
    {tb_systolic_array      tb_systolic_array.sv      500000}
    {tb_axi_csr             tb_axi_csr.sv             300000}
    {tb_axis_sink           tb_axis_sink.sv           300000}
    {tb_axis_source         tb_axis_source.sv         300000}
    {tb_top_integration     tb_top_integration.sv     2000000}
    {streaming_topk_tb      streaming_topk_tb.sv      200000}
    {bbox_decoder_dfl_tb    bbox_decoder_dfl_tb.sv    200000}
    {sparse_candidate_packer_tb  sparse_candidate_packer_tb.sv  200000}
    {npu_detection_head_tb  npu_detection_head_tb.sv  300000}
}

set pass_count 0
set fail_count 0
set skip_count 0
set results {}

puts ""
puts "============================================================"
puts " TinyNPU200A Verification Regression Suite"
puts " [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts "============================================================"

# --------------------------------------------------------------------------
# Step 1: Compile all RTL sources (xvlog)
# --------------------------------------------------------------------------
puts "\n\[COMPILE\] Compiling RTL sources..."
set compile_ok 1
foreach src \ {
    set fpath [file join \ \]
    if {![file exists \]} {
        puts "  \[WARN\] Not found: \"
        continue
    }
    set rc [catch {exec xvlog --sv \ 2>@1} msg]
    if {\ != 0} {
        puts "  \[ERROR\] Compile failed: \"
        puts \
        set compile_ok 0
    } else {
        puts "  \[OK\]  \"
    }
}

# Also compile existing ADAS detection head RTL
set ADAS_SOURCES {npu_detection_head bbox_decoder_dfl sparse_candidate_packer streaming_topk}
foreach mod \ {
    set fpath [file join \ IP/NPU300PMADAS/src/\.v]
    if {[file exists \]} {
        set rc [catch {exec xvlog --sv \ 2>@1} msg]
        if {\ == 0} { puts "  \[OK\]  \.v (NPU300PM)" }
    } else {
        # Try TinyNPU200 src
        set fpath2 [file join \ \.v]
        if {[file exists \]} {
            set rc [catch {exec xvlog --sv \ 2>@1} msg]
            if {\ == 0} { puts "  \[OK\]  \.v (TinyNPU200 src)" }
        }
    }
}

if {!\} {
    puts "\n\[ABORT\] RTL compilation errors. Fix before running testbenches."
    return
}

# --------------------------------------------------------------------------
# Step 2: Run each testbench
# --------------------------------------------------------------------------
puts "\n\[SIMULATE\] Running testbenches...\n"

foreach tb_entry \ {
    set top_module [lindex \ 0]
    set tb_file    [lindex \ 1]
    set timeout_ns [lindex \ 2]
    set tb_path    [file join \ \]
    set snap_name  [string tolower \]

    puts "----------------------------------------------"
    puts " TB: \"
    puts "----------------------------------------------"

    if {![file exists \]} {
        puts "  \[SKIP\] File not found: \"
        incr skip_count
        lappend results [list \ SKIP]
        continue
    }

    # Compile testbench
    set rc [catch {exec xvlog --sv \ 2>@1} msg]
    if {\ != 0} {
        puts "  \[ERROR\] TB compile failed:"
        puts \
        incr fail_count
        lappend results [list \ COMPILE_ERROR]
        continue
    }

    # Elaborate
    set rc [catch {exec xelab \ -debug typical -s \ 2>@1} elab_msg]
    if {\ != 0} {
        puts "  \[ERROR\] Elaboration failed:"
        puts \
        incr fail_count
        lappend results [list \ ELAB_ERROR]
        continue
    }

    # Simulate & capture log
    set log_file [file join \ \.log]
    set xsim_tcl "log_wave -recursive *; run \ns; quit"
    set rc [catch {exec xsim \ -tclbatch [list puts \ | xsim] 2>@1} sim_msg]

    # Run using -R (run to completion) 
    set rc2 [catch {exec xsim \ -R 2>@1} sim_output]
    set f [open \ w]
    puts \ \
    close \

    # Parse result: look for FAIL keyword or assertion errors
    set passed 1
    if {[string match "*FAIL*" \] || 
        [string match "*ERROR*" \] ||
        [string match "*error*" \] ||
        [string match "*Assertion*" \]} {
        set passed 0
    }
    if {![string match "*PASS*" \] && !\} {
        set passed 0
    }

    if {\} {
        puts "  \[PASS\] \"
        incr pass_count
        lappend results [list \ PASS]
    } else {
        puts "  \[FAIL\] \  -- see \"
        puts "  Output excerpt:"
        set lines [split \ \n]
        set count 0
        foreach line \ {
            if {[string match "*FAIL*" \] || [string match "*ERROR*" \] || 
                [string match "*error*" \] || [string match "*PASS*" \]} {
                puts "    \"
                incr count
                if {\ > 10} break
            }
        }
        incr fail_count
        lappend results [list \ FAIL]
    }
}

# --------------------------------------------------------------------------
# Step 3: Final summary
# --------------------------------------------------------------------------
set total [expr {\ + \ + \}]
puts ""
puts "============================================================"
puts " REGRESSION SUMMARY"
puts "============================================================"
puts [format " %-40s %s" "Testbench" "Result"]
puts " [string repeat - 50]"
foreach r \ {
    puts [format " %-40s %s" [lindex \ 0] [lindex \ 1]]
}
puts " [string repeat - 50]"
puts " Total: \ | Pass: \ | Fail: \ | Skip: \"
puts ""
if {\ == 0 && \ == 0} {
    puts " RESULT: *** ALL TESTS PASSED ***"
} elseif {\ == 0} {
    puts " RESULT: PASS (with \ skipped)"
} else {
    puts " RESULT: *** REGRESSION FAILED (\ failures) ***"
}
puts "============================================================"
puts " Logs: \"
puts "============================================================"
