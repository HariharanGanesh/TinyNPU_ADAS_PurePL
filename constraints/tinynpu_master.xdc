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
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets npu_system_i/ps7/inst/FCLK_CLK0]

# ==============================================================================
# 4. Timing Closures
# ==============================================================================
# Define the incoming HDMI pixel clock (720p = 74.25 MHz = 13.468 ns)
create_clock -period 13.468 -name TMDS_RX_clk_p -waveform {0.000 6.734} [get_ports TMDS_RX_clk_p]

# False path for asynchronous HDMI lock status crossing to 125 MHz NPU domain
set_false_path -from [get_clocks clk_fpga_1] -to [get_clocks clk_fpga_0]
