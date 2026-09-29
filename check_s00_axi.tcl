open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]

puts "--- PROPERTIES OF S00_AXI ---"
report_property [get_bd_intf_pins /axi_mem_intercon/S00_AXI]
puts "--- DONE ---"
