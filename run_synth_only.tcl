open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips npu_system_tinynpu_0_0] -no_script -sync -force -quiet
reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
