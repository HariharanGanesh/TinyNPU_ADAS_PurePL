# rebuild_all.tcl

# Change working directory to ensure glob paths in package_ip.tcl work correctly
cd "D:/Final year project"

# 1. Package IP
source "package_ip.tcl"

# 2. Open project safely
set proj_path "D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system/tinynpu_pynq_system.xpr"
set proj_name [file rootname [file tail $proj_path]]
if {[catch {current_project} cur_proj] || $cur_proj ne $proj_name} {
    open_project "$proj_path"
} else {
    puts "INFO: Project $proj_name is already open."
}

# 3. Upgrade IP
update_ip_catalog -rebuild
set locked_ips [get_ips -filter {IS_LOCKED==1 || UPGRADE_VERSIONS!=""}]
if {[llength $locked_ips] > 0} {
    puts "Upgrading IPs: $locked_ips"
    upgrade_ip $locked_ips
}

# 4. Generate BD targets
generate_target all [get_files *.bd]

# 5. Run synth and impl
reset_run synth_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 6. Report timing
open_run impl_1
report_timing_summary -file "D:/Final year project/final_timing_summary.txt"
report_timing -max_paths 10 -nworst 1 -setup -file "D:/Final year project/final_critical_paths.txt"
puts "Rebuild and timing analysis complete!"
