open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr

# Create simulation fileset
if {[string equal [get_filesets -quiet sim_hdmi_e2e] ""]} {
    create_fileset -simset sim_hdmi_e2e
}

# Add testbench
add_files -fileset sim_hdmi_e2e -norecurse verification/tb/tb_hdmi_e2e.sv
set_property FILE_TYPE SystemVerilog [get_files -of_objects [get_filesets sim_hdmi_e2e] -filter {NAME =~ *tb_hdmi_e2e.sv}]

# Set top
set_property top tb_hdmi_e2e [get_filesets sim_hdmi_e2e]
set_property top_lib xil_defaultlib [get_filesets sim_hdmi_e2e]

# Set simulator language to Mixed
set_property simulator_language Mixed [current_project]

# Set runtime to something large
set_property -name {xsim.simulate.runtime} -value {50ms} -objects [get_filesets sim_hdmi_e2e]

update_compile_order -fileset sim_hdmi_e2e