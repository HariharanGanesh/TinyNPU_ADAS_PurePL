open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"

# 1. Update IP Repositories to only point to the right NPU and the Digilent library
set_property ip_repo_paths [list "D:/Final year project/IP/NPU300PM" "D:/Final year project/Shared/IP/digilent-vivado-library"] [current_project]
update_ip_catalog -rebuild

# 2. Clear IP Cache to force fresh compile
config_ip_cache -clear_local_cache

# 3. Open BD and force upgrade
open_bd_design [get_files *.bd]
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips *tinynpu*]

# 4. Force BD product reset and regeneration
reset_target all [get_files *.bd]
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips *tinynpu*] -no_script -sync -force -quiet

# 5. Clean Synthesis run
reset_run synth_1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
launch_runs synth_1 -jobs 6
wait_on_run synth_1
puts "--- CLEAN SYNTHESIS DONE ---"
exit
