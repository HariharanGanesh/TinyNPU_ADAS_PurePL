# ==============================================================================
# PYNQ-Z2 ADAS NPU PIN CONSTRAINTS
# ==============================================================================

# ------------------------------------------------------------------------------
# System Clock (125 MHz on H16)
# ------------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4.000} [get_ports sysclk]

# ------------------------------------------------------------------------------
# Reset & Switches
# ------------------------------------------------------------------------------
# Button 0 (D19) -> ext_reset
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports ext_reset]

# Switch 0 (M20) -> sw_brake_arm
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports sw_brake_arm]

# ------------------------------------------------------------------------------
# LEDs (ADAS Warnings)
# ------------------------------------------------------------------------------
# LED 0 (R14) -> Lane Warning
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports out_warning_lane]
# LED 1 (P14) -> Pedestrian Warning
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports out_warning_ped]
# LED 2 (N16) -> Sign Warning
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports out_warning_sign]
# LED 3 (M14) -> Brake Authorized
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports out_brake_authorized]

# RGB LED 4 (L15) -> System Fault
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports out_system_fault]


# ------------------------------------------------------------------------------
# HDMI RX (Input from Camera)
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_p]

set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[2]}]

set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {rx_hpd[0]}]

set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports DDC_RX_scl_io]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports DDC_RX_sda_io]


# ------------------------------------------------------------------------------
# HDMI TX (Output to Monitor)
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_p]

set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[0]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[2]}]

set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports tx_hpd]

# ------------------------------------------------------------------------------
# Internal Digilent IP Workarounds
# ------------------------------------------------------------------------------
set_property -quiet DONT_TOUCH true [get_cells -quiet -hierarchical -filter {NAME =~ u_dvi2rgb/*}]
set_property -quiet SEVERITY {WARNING} [get_drc_checks -quiet {NDRV-1}]
set_property -quiet CLOCK_DEDICATED_ROUTE FALSE [get_nets -quiet npu_system_i/clk_wiz_0/inst/clk_out1]