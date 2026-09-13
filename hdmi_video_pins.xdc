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

set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports DDC_RX_scl_io]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports DDC_RX_sda_io]

# ==============================================================================
# HDMI TX (Output to Monitor)
# ==============================================================================
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_TX_clk_p]

set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[0]}]

set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[1]}]

set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_TX_data_p[2]}]
