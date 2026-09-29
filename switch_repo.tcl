open_project ./RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts [get_property ip_repo_paths [current_project]]
set_property ip_repo_paths { {D:/Final year project/IP/TinyNPU200} {D:/Final year project/Shared/IP/digilent-vivado-library} } [current_project]
update_ip_catalog -rebuild
upgrade_ip [get_ips *tinynpu*]
report_ip_status
close_project
