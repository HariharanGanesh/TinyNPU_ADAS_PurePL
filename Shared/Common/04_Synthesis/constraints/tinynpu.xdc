## =============================================================================
## tinynpu.xdc — Timing Constraints for TinyNPU v2.0
## Target:  PYNQ-Z2 (XC7Z020CLG400-1)
##
## The PYNQ-Z2 PS supplies the PL with a 100 MHz FCLK_CLK0 by default.
## TinyNPU targets 100 MHz for conservative Fmax with headroom.
## Upgrade to 200 MHz by reconfiguring the PS MMCM if needed.
##
## NOTE: The PS-to-PL clock (FCLK_CLK0) is instantiated as a clock input
##       on port 'clk'. In a BD design, replace [get_ports clk] with
##       the actual net from the Zynq PS7 IP block output.
## =============================================================================

## -----------------------------------------------------------------------------
## Primary Clock — 100 MHz (10 ns period)
## Source: Zynq PS FCLK_CLK0 → PL fabric
## -----------------------------------------------------------------------------
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

## -----------------------------------------------------------------------------
## Generated Clocks — BUFGCE gated domains
## All three are gated derivatives of the primary clock.
## Vivado will automatically derive these from the BUFGCE output nets.
## Explicitly declaring prevents CDC false-path violations.
## -----------------------------------------------------------------------------



## -----------------------------------------------------------------------------
## CDC False Paths
## The three gated clocks are derived from the same root clock and are
## only ever gated (not phase-shifted). Registers crossing between them
## are safe because enable signals change only on the rising edge of the
## root clock. Declare as false paths to suppress spurious timing errors.
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## I/O Timing (Conservative estimates — refine after board-level measurement)
## AXI4-Lite and AXI4-Stream ports driven by the PS AXI Interconnect at 100 MHz
## -----------------------------------------------------------------------------
set _xlnx_shared_i0 [get_ports {s_axi_* s_axis_* m_axi_r* m_axi_b*}]
set_input_delay -clock clk -max 2.000 $_xlnx_shared_i0
set_input_delay -clock clk -min 0.500 $_xlnx_shared_i0
set _xlnx_shared_i1 [get_ports {s_axi_* m_axi_* m_axis_* interrupt}]
set_output_delay -clock clk -max 2.000 $_xlnx_shared_i1
set_output_delay -clock clk -min 0.500 $_xlnx_shared_i1

## -----------------------------------------------------------------------------
## Reset — asynchronous assert, synchronous deassert (no timing needed on async)
## -----------------------------------------------------------------------------
set_false_path -from [get_ports rst_n]

