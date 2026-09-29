open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild -repo_path "D:/Final year project/IP/TinyNPU200"
catch { upgrade_ip [get_ips npu_system_tinynpu_0_0] }

puts "GENERATING BLOCK DESIGN OUTPUT PRODUCTS..."
generate_target all [get_files "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"]
export_ip_user_files -of_objects [get_files "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"] -no_script -sync -force -quiet

puts "LAUNCHING SYNTHESIS AND IMPLEMENTATION..."
reset_run synth_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1
puts "IMPLEMENTATION FINISHED!"
exit
