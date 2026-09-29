# export_bd_pdf.tcl
open_project "D:/Final year project/npu200jpmax/npu200jb.xpr"
open_bd_design [get_files *.bd]
write_bd_layout -format pdf -orientation landscape "D:/Final year project/reports/NPU300PM_Block_Design.pdf"
exit
