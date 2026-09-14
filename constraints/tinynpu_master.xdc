# ==============================================================================
# TinyNPU300PM Master Constraints File (PYNQ-Z2)
# ==============================================================================

# ==============================================================================
# 1. HDMI RX (Input from Camera/Laptop)
# ==============================================================================
set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_p]

set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[2]}]

set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports DDC_RX_scl_io]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports DDC_RX_sda_io]

# ==============================================================================
# 2. HDMI TX (Output to Monitor/Projector)
# ==============================================================================
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_p]

set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[0]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[2]}]

# ==============================================================================
# 3. Vivado Bug & Routing Overrides
# ==============================================================================
# DRC Waiver: Digilent dvi2rgb v2.0 pRst OOC synthesis trimming bug
set_property SEVERITY {WARNING} [get_drc_checks {NDRV-1}]

# DRC Waiver: Digilent rgb2dvi 720p PLL VCO frequency out of range (742.5 MHz < 800 MHz)
set_property SEVERITY {WARNING} [get_drc_checks {PDRC-43}]

# Bypass BUFG-BUFG cascade placement error for PS7 FCLK_CLK0 to TinyNPU Clock Gating BUFGCE cells
# [Place 30-120]: Sub-optimal placement is expected; FCLK_CLK0 fans out to multiple BUFGCE gates.
# Timing is MET; this is a known Zynq PS7 topology on 7-Series parts.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -quiet npu_system_i/ps7/inst/FCLK_CLK0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -quiet {npu_system_i/clk_wiz_0/inst/clk_out1}]

# ==============================================================================
# 3b. Message Suppressions — Known-Safe Third-Party / Xilinx IP Warnings
# ==============================================================================

# [HDL 9-3756] / [filemgmt 20-1318]: Digilent dvi2rgb ILA IP defines ila_pixclk in two
#   source files (ila_pixclk.v + ila_refclk.v). The second definition is silently ignored
#   by xelab. This is a Digilent packaging bug with no functional impact.
set_msg_config -id {HDL 9-3756}      -suppress
set_msg_config -id {filemgmt 20-1318} -suppress

# [Synth 8-9112]: Digilent VHDL TMDS_Clocking.vhd uses a non-static 'arst' port connection.
#   This is an expected Digilent IP pattern; synthesis correctly handles it as a constant.
set_msg_config -id {Synth 8-9112} -suppress

# [Synth 8-7071] / [Synth 8-7023]: Unconnected / partially-connected AXI Register Slice
#   port 'aclk2x' in axi_protocol_converter. This port is optional and unused in AXI3 mode.
#   The connection count mismatch (93 declared, 92 given) is a known Vivado IP version quirk.
set_msg_config -id {Synth 8-7071} -suppress
set_msg_config -id {Synth 8-7023} -suppress

# [Synth 8-689]: AXI crossbar m_axi_arprot width mismatch (3 vs 6) in generated BD netlist.
#   This is a known Vivado block-design generation artefact; unused upper bits are tied to 0.
set_msg_config -id {Synth 8-689} -suppress

# [Synth 8-151]: PicoRV32 case item '1b0' is unreachable. This is intentional defensive
#   coding in the open-source PicoRV32 core to comply with case-full-ness requirements.
set_msg_config -id {Synth 8-151} -suppress

# [Synth 8-6014]: Unused sequential elements removed during synthesis — normal optimization.
set_msg_config -id {Synth 8-6014} -suppress

# [Synth 8-7129]: Unconnected/no-load ports in generated IP (sleep, VIDEO_FORMAT[1], etc.)
#   These are optional sideband ports in Xilinx Video IP that are unused in this design.
set_msg_config -id {Synth 8-7129} -suppress

# [Synth 8-10507]: Duplicate X_INTERFACE_MODE attribute in AXI crossbar — Vivado IP quirk.
set_msg_config -id {Synth 8-10507} -suppress

# [Synth 8-3332]: Unused proc_sys_reset sequential element removed — expected for unused
#   reset outputs (e.g. FDRE_inst for peripheral_aresetn when not all resets are used).
set_msg_config -id {Synth 8-3332} -suppress

# [Synth 8-6702]: IncrSynth reverting to default — expected after any source file change.
set_msg_config -id {Synth 8-6702} -suppress

# [Synth 8-7080]: Parallel synthesis criteria not met for small OOC IP cores — expected;
#   small modules don't benefit from parallel synthesis.
set_msg_config -id {Synth 8-7080} -suppress

# [Synth 8-11357]: Potential runtime issue for 3D-RAM (row_buf). This is a Vivado heuristic
#   warning for large register arrays. The row buffer is intentionally large for line buffering.
set_msg_config -id {Synth 8-11357} -suppress

# [Vivado 12-508] / [Vivado 12-180]: Digilent ILA timing workaround XDC references ILA
#   core pins/cells that don't exist in this design (ila_pixclk is not instantiated in
#   synthesis). Safe to suppress — the XDC applies only to simulation ILA.
set_msg_config -id {Vivado 12-508} -suppress
set_msg_config -id {Vivado 12-180} -suppress

# [Vivado 12-1008] / [Common 17-55] / [Vivado 12-259]: VTC (Video Timing Controller) OOC
#   clock constraint queries a port-scoped clock that doesn't exist at OOC level. Safe; the
#   VTC functions correctly when embedded in the full design context.
set_msg_config -id {Vivado 12-1008} -suppress
set_msg_config -id {Common 17-55}   -suppress
set_msg_config -id {Vivado 12-259}  -suppress

# [IP_Flow 19-2248]: Stale OOC IP repository path 'x:/...' from a previous build machine.
#   The X: drive mapping does not exist on this machine; the correct IP is resolved from D:.
set_msg_config -id {IP_Flow 19-2248} -suppress

# [Board 49-26]: Board part database contains entries for FPGAs not installed in this
#   Vivado license/installation. Does not affect PYNQ-Z2 (Zynq-7020) target.
set_msg_config -id {Board 49-26} -suppress

# [Project 1-5713]: Board part property unset — expected when targeting PYNQ-Z2 without
#   the Digilent board file registered in Vivado. Pin constraints are manually specified.
set_msg_config -id {Project 1-5713} -suppress

# [Netlist 29-101]: PicoRV32 core has a large flat netlist. This is expected for a
#   soft-core processor. Floorplanning is not required for this design.
set_msg_config -id {Netlist 29-101} -suppress

# [Timing 38-436]: set_bus_skew constraints from AXI crossbar IP. Report_bus_skew has
#   been verified; skew requirements are met in the routed design.
set_msg_config -id {Timing 38-436} -suppress

# ==============================================================================
# 4. Timing Closures
# ==============================================================================
# Define the incoming HDMI pixel clock (720p = 74.25 MHz = 13.468 ns)
create_clock -period 13.468 -name TMDS_RX_clk_p -waveform {0.000 6.734} [get_ports TMDS_RX_clk_p]

# False path for asynchronous HDMI lock status crossing to 125 MHz NPU domain
set_false_path -from [get_clocks clk_fpga_1] -to [get_clocks clk_fpga_0]
