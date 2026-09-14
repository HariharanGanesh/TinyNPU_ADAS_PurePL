cd "D:/Final year project"
open_project "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
open_bd_design [get_files *.bd]

puts "--- 1. Updating IP Catalog and Upgrading Locked IPs ---"
update_ip_catalog
set locked_ips [get_ips -filter {IS_LOCKED == 1}]
if {$locked_ips ne ""} {
    puts "Found locked IPs: $locked_ips"
    catch {upgrade_ip $locked_ips}
} else {
    puts "No locked IPs found."
}

# The IP upgrade might reset some connections or properties, but the previous script already saved them if they succeeded.
# Just to be safe, save again.
save_bd_design

puts "--- 2. Regenerating targets ---"
# Force target regeneration
reset_target all [get_files *.bd]
generate_target all [get_files *.bd]

puts "--- 3. Launching Synthesis and Implementation ---"
reset_run synth_1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "--- ALL TASKS COMPLETE ---"
exit
