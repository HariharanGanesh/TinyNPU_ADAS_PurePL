open_project {D:/Final year project/npu200jpmax/npu200jpmax.xpr}
update_ip_catalog -rebuild
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips *tinynpu_0*]

# Use get_files by name to avoid space issues
generate_target all [get_files npu_system.bd]

# Reset ALL synthesis runs
reset_run [get_runs *synth_1*]

launch_runs synth_1 -jobs 2
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
