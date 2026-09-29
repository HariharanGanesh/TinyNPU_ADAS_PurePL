open_project ./RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set_property ip_repo_paths { {D:/Final year project/IP/TinyNPU200} {D:/Final year project/Shared/IP/digilent-vivado-library} } [current_project]
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
