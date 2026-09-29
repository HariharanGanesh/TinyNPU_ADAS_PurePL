open_checkpoint "D:/Final year project/vivado_npu200j_proj/npu200j.runs/impl_1/tinynpu_hdmi_top_routed.dcp"
write_bitstream -force "D:/Final year project/vivado_npu200j_proj/npu200j.runs/impl_1/tinynpu_hdmi_top.bit"
file copy -force "D:/Final year project/vivado_npu200j_proj/npu200j.runs/impl_1/tinynpu_hdmi_top.bit" "D:/Final year project/TinyNPU200.bit"
puts "SUCCESS: Bitstream generated and copied!"
