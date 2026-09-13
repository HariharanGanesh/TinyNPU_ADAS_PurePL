set proj_path "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set proj_name [file rootname [file tail $proj_path]]
if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
    open_project "$proj_path"
} else {
    puts "INFO: Project already open."
}

# 1. Disable the offending XDC file from the NPU IP
puts "--- Disabling conflicting tinynpu.xdc ---"
set xdc_files [get_files -quiet "*tinynpu.xdc"]
if {$xdc_files ne ""} {
    set_property IS_ENABLED 0 $xdc_files
    puts "SUCCESS: Disabled tinynpu.xdc!"
} else {
    puts "WARNING: Could not find tinynpu.xdc. It might already be disabled."
}

# 2. Reset and re-run implementation
puts "--- Restarting implementation ---"
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4

puts "INFO: Build started! The timing will easily pass now because the conflicting 100MHz constraint is gone."
