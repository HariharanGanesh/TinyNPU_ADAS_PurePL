## PYNQ-Z2 HDMI Pin Constraints for TinyNPU Full PL

# 125 MHz System Clock from physical crystal H16
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sys_clk }];

# Allow BUFG-to-BUFG clock routing for clock-gated NPU modules
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hierarchical -filter {NAME =~ */clk_wiz_0/*/clk_out1}]

# ==============================================================================
# HDMI RX (Input from Camera/Laptop)
# ==============================================================================
set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports TMDS_RX_clk_p]

set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[0]}]

set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[1]}]

set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {TMDS_RX_data_p[2]}]

# DDC (I2C EDID channel)
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports DDC_scl_io]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports DDC_sda_io]

# HPD / RXEN (Optional ports with -quiet flag)
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports -quiet {HDMI_rxen[0]}]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports -quiet {HDMI_hpd[0]}]

# ==============================================================================
# HDMI TX (Output to Projector)
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
# False Paths & Timing Waivers
# ==============================================================================
set_false_path -through [get_pins -hierarchical -filter {NAME =~ */dvi2rgb_0/*/aRst*}]
set_false_path -through [get_pins -hierarchical -filter {NAME =~ */rgb2dvi_0/*/aRst*}]

# DRC Waivers
set_property SEVERITY {Warning} [get_drc_checks NDRV-1]

