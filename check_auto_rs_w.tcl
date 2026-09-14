open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
open_bd_design [get_files *.bd]

puts "--- PROPERTIES OF auto_rs_w ---"
report_property [get_bd_cells /axi_mem_intercon/s00_couplers/auto_rs_w]
puts "--- DONE ---"
