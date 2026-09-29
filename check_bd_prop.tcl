open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]

set intf [get_bd_intf_pins /tinynpu_0/m_axi]
puts "--- PROPERTIES OF /tinynpu_0/m_axi ---"
report_property $intf
puts "--- DONE ---"
