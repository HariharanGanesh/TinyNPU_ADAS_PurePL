open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set_property top tb_hdmi_e2e [get_filesets sim_hdmi_e2e]
current_fileset -simset [ get_filesets sim_hdmi_e2e ]
launch_simulation -simset sim_hdmi_e2e