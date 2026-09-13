# create_pure_pl_adas.tcl
set proj_path "X:/"

# 1. Open existing project
open_project "${proj_path}RISCV_ADAS_NPU300/RISCV_ADAS_NPU300.xpr"

# 2. Save As to create the new Pure-PL project
save_project_as RISCV_ADAS_PURE_PL "${proj_path}RISCV_ADAS_PURE_PL" -force

# 3. Add the firmware hex file as a simulation/synthesis source
add_files -fileset sources_1 "${proj_path}IP/RISCV_ADAS_Controller/sw/firmware.hex"
set_property file_type "Memory File" [get_files "${proj_path}IP/RISCV_ADAS_Controller/sw/firmware.hex"]

# 4. Open Block Design
open_bd_design [get_files *.bd]

# 5. RIP OUT THE ZYNQ ARM CORTEX-A9
delete_bd_objs [get_bd_cells ps7]
delete_bd_objs [get_bd_cells rst_ps7_125M]

# 6. Add PL Clocking Wizard (MMCM) and System Reset
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000}] [get_bd_cells clk_wiz_0]
make_bd_pins_external  [get_bd_pins clk_wiz_0/clk_in1]
set_property name sysclk [get_bd_ports clk_in1_0]
make_bd_pins_external  [get_bd_pins clk_wiz_0/reset]
set_property name ext_reset [get_bd_ports reset_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net [get_bd_ports ext_reset] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# 7. Route Clocks to the rest of the system
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins tinynpu_0/clk]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins riscv_adas_0/clk]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/ACLK]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/S00_ACLK]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_mem_intercon/M00_ACLK]}

catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins dvi2rgb_0/RefClk]}
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins tinynpu_0/clk_200]}

# 8. Route Resets
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins tinynpu_0/rst_n]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins riscv_adas_0/rst_n]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_mem_intercon/ARESETN]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_mem_intercon/S00_ARESETN]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_mem_intercon/M00_ARESETN]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_mem_intercon/M01_ARESETN]}

# 9. Recreate RISC-V Subsystem IP block
# (Updating existing module crashes Vivado due to port mismatch bugs, so we recreate it)
delete_bd_objs [get_bd_cells riscv_adas_0]
create_bd_cell -type module -reference riscv_adas_subsystem riscv_adas_0

# Re-route standard connections to the new riscv_adas_0 cell
catch {connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins riscv_adas_0/clk]}
catch {connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins riscv_adas_0/rst_n]}
# (Safety IO nets are ignored for now since they are made external separately, but let's re-make them external)
catch {make_bd_pins_external [get_bd_pins riscv_adas_0/out_warning_ped]}
catch {make_bd_pins_external [get_bd_pins riscv_adas_0/out_warning_lane]}
catch {make_bd_pins_external [get_bd_pins riscv_adas_0/out_warning_sign]}
catch {make_bd_pins_external [get_bd_pins riscv_adas_0/out_brake_authorized]}
catch {make_bd_pins_external [get_bd_pins riscv_adas_0/out_system_fault]}

# 10. Connect RISC-V AXI Master to AXI Interconnect
catch {connect_bd_intf_net [get_bd_intf_pins riscv_adas_0/m_axi] [get_bd_intf_pins axi_mem_intercon/S00_AXI]}

# 11. Connect AXI Interconnect to NPU CSR Slave
# Note: In the previous design, M00_AXI was connected to the NPU CSRs from the PS7.
# Since PS7 is deleted, M00 is already connected to NPU! We just connected the RISC-V to S00.

# 12. Regenerate Layout, Validate, Save
regenerate_bd_layout
validate_bd_design
save_bd_design

# 13. Update Wrapper
make_wrapper -files [get_files *.bd] -top
set wrapper_file "${proj_path}RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.gen/sources_1/bd/npu_system/hdl/npu_system_wrapper.v"
add_files -norecurse "$wrapper_file"
update_compile_order -fileset sources_1

# 14. Launch Synthesis
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 15. Report timing
open_run synth_1 -name synth_1
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_PURE_PL_Timing.rpt"

exit
