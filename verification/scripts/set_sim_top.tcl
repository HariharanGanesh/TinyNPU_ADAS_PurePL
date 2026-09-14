open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set_property top tb_hdmi_e2e [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
save_project_as RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr -force