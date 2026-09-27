# =============================================================================
# run_regression.tcl
# =============================================================================

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RTL_DIR_1 [file join $PROJ_ROOT IP/TinyNPU200/src]
set RTL_DIR_2 [file join $PROJ_ROOT IP/NPU300PMADAS/src]
set VERIF_DIR [file join $PROJ_ROOT verification/tb]
set LOG_DIR   [file join $PROJ_ROOT verification/regression_logs]

file mkdir $LOG_DIR

# 1. Compile all RTL
set RTL_FILES [glob -nocomplain [file join $RTL_DIR_1 *.v] [file join $RTL_DIR_1 *.sv] [file join $RTL_DIR_2 *.v] [file join $RTL_DIR_2 *.sv]]
set RTL_FILES [lsearch -all -inline -not -exact $RTL_FILES [file join $RTL_DIR_2 tinynpu_top_adas.v]]
set compile_ok 1
foreach f $RTL_FILES {
    puts "Compiling RTL: $f"
    if {[catch {exec xvlog --sv $f} msg]} {
        puts "ERROR: $msg"
        set compile_ok 0
    }
}

set glbl_file "$::env(XILINX_VIVADO)/data/verilog/src/glbl.v"
if {[file exists $glbl_file]} {
    puts "Compiling glbl.v"
    catch {exec xvlog $glbl_file}
}

if {!$compile_ok} {
    puts "RTL Compilation failed!"
    exit 1
}

# 2. Compile and run testbenches
set TB_LIST {
    tb_processing_element
    tb_systolic_array
    tb_axi_csr
    tb_axis_sink
    tb_axis_source
    streaming_topk_tb
    bbox_decoder_dfl_tb
    sparse_candidate_packer_tb
    npu_detection_head_tb
    tb_top_integration
}

set pass_count 0
set fail_count 0

foreach tb_name $TB_LIST {
    set tb_file [file join $VERIF_DIR ${tb_name}.sv]
    if {![file exists $tb_file]} {
        set tb_file [file join $VERIF_DIR ${tb_name}.v]
    }
    
    if {![file exists $tb_file]} {
        puts "SKIP: $tb_name not found"
        continue
    }
    
    puts "Running TB: $tb_name"
    if {[catch {exec xvlog --sv $tb_file} msg]} {
        puts "ERROR: TB Compilation failed for $tb_name\n$msg"
        incr fail_count
        continue
    }
    
    if {[catch {exec xelab -L unisims_ver -L unimacro_ver -L secureip -L xpm glbl -debug typical $tb_name -s $tb_name} msg]} {
        puts "ERROR: Elaboration failed for $tb_name\n$msg"
        incr fail_count
        continue
    }
    
    if {[catch {exec xsim $tb_name -R} sim_out]} {
        # xsim might return non-zero exit code if assertion fails or $fatal is called. We still want to check the output.
        # So we just capture it.
    }
    
    # Run it properly to capture output, or just use sim_out from above since exec captures stdout
    # Wait, if xsim fails, catch puts the output into sim_out.
    set log_file [file join $LOG_DIR ${tb_name}.log]
    set fd [open $log_file w]
    puts $fd $sim_out
    close $fd
    
    if {[string match "*TB_RESULT: FAIL*" $sim_out] || [string match "*Error*" $sim_out] || [string match "*Fatal*" $sim_out] || ![string match "*TB_RESULT: PASS*" $sim_out]} {
        puts "FAIL: $tb_name"
        incr fail_count
    } else {
        puts "PASS: $tb_name"
        incr pass_count
    }
}

puts "Regression Summary: PASS: $pass_count, FAIL: $fail_count"
if {$fail_count > 0} {
    exit 1
}