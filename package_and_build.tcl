# package_and_build.tcl
cd "D:/Final year project"

# 1. Package the new IP
create_project -in_memory -part xc7z020clg400-1
add_files "IP/NPU300PMADAS/src/streaming_topk.v"
add_files "IP/NPU300PMADAS/src/bbox_decoder_dfl.v"
add_files "IP/NPU300PMADAS/src/sparse_candidate_packer.v"
add_files "IP/NPU300PMADAS/src/npu_detection_head.v"
add_files "IP/NPU300PMADAS/src/tinynpu_top_adas.v"

ipx::package_project -root_dir "IP/NPU300PMADAS" -vendor user.org -library user -taxonomy /UserIP
set_property name NPU300PMADAS [ipx::current_core]
set_property version 1.0 [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

# 2. Open the main project and update IP
open_project "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild
upgrade_ip [get_ips]

# 3. Generate Bitstream
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "Implementation Run Status: [get_property STATUS [get_runs impl_1]]"
exit
