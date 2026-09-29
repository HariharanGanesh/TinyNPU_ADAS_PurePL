open_project "D:/Final year project/tinynpu_ip_viewer/tinynpu_ip_viewer.xpr"
update_compile_order -fileset sources_1
synth_design -rtl -name rtl_1
report_drc -name drc_1
puts "--- SYNTAX CHECK DONE ---"
