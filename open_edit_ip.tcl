open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
update_compile_order -fileset sources_1
catch { ipx::edit_ip_in_project -upgrade true -name edit_tinynpu -directory {D:/edit_tinynpu} {D:/Final year project/IP/NPU300PM/component.xml} }
update_compile_order -fileset sources_1
start_gui
