puts "Repackaging NPU300PM IP..."
set core [ipx::open_core ./IP/NPU300PM/component.xml]
ipx::merge_project_changes files $core
set revision [get_property core_revision $core]
incr revision
set_property core_revision $revision $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core

puts "Updating ADAS Project..."
open_project ./RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild
set locked_ips [get_ips -filter {IS_LOCKED == 1}]
if {[llength $locked_ips] > 0} {
    puts "Upgrading locked IPs: $locked_ips"
    upgrade_ip $locked_ips
} else {
    puts "No locked IPs found. Attempting to upgrade by name..."
    catch {upgrade_ip [get_ips *tinynpu*]}
}
report_ip_status
close_project
