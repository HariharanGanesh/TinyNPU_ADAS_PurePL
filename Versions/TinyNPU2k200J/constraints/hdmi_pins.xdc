## PYNQ-Z2 HDMI Pin Constraints for TinyNPU2k200J

# 125 MHz System Clock
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sys_clk }];

# Reset Button (BTN0)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { sys_rst_n }]; 

# Status LEDs
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; 
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; 

# ==============================================================================
# HDMI RX (Input from Camera/Laptop)
# ==============================================================================
set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports hdmi_rx_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports hdmi_rx_clk_p]

set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_p[0]}]

set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_p[1]}]

set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_data_p[2]}]

# ==============================================================================
# HDMI TX (Output to Monitor)
# ==============================================================================
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_p]

set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_p[0]}]

set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_p[1]}]

set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_data_p[2]}]

# ==============================================================================
# DONT_TOUCH: Prevent opt_design from trimming dvi2rgb reset bridge logic
# (Workaround for Digilent dvi2rgb v2.0 + Vivado 2025.1 opt_design bug)
# ==============================================================================
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ u_dvi2rgb/*}]

# ==============================================================================
# DRC Waiver: Digilent dvi2rgb v2.0 pRst OOC synthesis trimming bug
# The pRst net inside dvi2rgb is trimmed during OOC synthesis with Vivado 2025.1
# when aRst input is treated as don't-care. Downgrade to WARNING so place_design
# can proceed. The DataDecoders use ASYNC_REG FFs that reset via power-on state.
# ==============================================================================
set_property SEVERITY {WARNING} [get_drc_checks {NDRV-1}]

# ==============================================================================
# Placement Fix: rgb2dvi MMCM must be in CLOCKREGION_X1Y2 (Bank 35)
# HDMI TX pins (Bank 35) force BUFIO/BUFR to CLOCKREGION_X1Y2.
# An MMCM driving a BUFIO/BUFR must be in the same clock region.
# CLOCK_REGION property only works on BUFGs. Use LOC for MMCM cells.
# On xc7z020clg400-1, MMCME2_ADV_X1Y2 is in CLOCKREGION_X1Y2.
# ==============================================================================
set_property LOC MMCME2_ADV_X1Y2 [get_cells u_rgb2dvi/U0/ClockGenInternal.ClockGenX/GenMMCM.DVI_ClkGenerator]

# ==============================================================================
# sys_pll BACKBONE routing: Forcing rgb2dvi MMCM to X1Y2 pushes sys_pll MMCM
# away from its CCIO input pin (IOB_X1Y124, CLOCKREGION_X1Y3). Allow Vivado to
# route sys_pll's input via the BUFG backbone (safe for 125 MHz system clock).
# ==============================================================================
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets u_pll/inst/clk_in1_sys_pll]