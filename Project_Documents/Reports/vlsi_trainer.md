# VLSI Trainer – TinyNPU Architecture & Vivado Issue Log

This document serves as a training dataset of real-world FPGA, RTL, and Vivado errors encountered during the TinyNPU200 design lifecycle, along with their root causes and verified solutions.

---

## 1. Verilog Submodule Port Instantiation Mismatch
**Error/Symptom:** Vivado Synthesis failed with errors stating ports were missing or undeclared during the elaboration phase of `tinynpu_top.v`. For example, `output_buffer` had `act_valid_in` mapped in the top-level, but the actual module port was `acc_valid`.
**Root Cause:** The top-level wrapper (`tinynpu_top.v`) was instantiating submodules using port names and parameter names that were stale or mismatched with the actual module definitions.
**Solution:** Conducted a comprehensive RTL audit comparing `tinynpu_top.v` instantiations against the exact module definitions (`module (...)`) for all sub-blocks. Rewrote all instantiations to ensure 100% 1-to-1 mapping of port names and parameter names.

## 2. Arithmetic Truncation Bug in Data Paths
**Error/Symptom:** During RTL review, a truncation bug was found in `weight_buffer.v`. The `write_row` register was sized as a 4-bit wire, but it was being assigned from a counter that needed to index up to 20 rows (which requires at least 5 bits).
**Root Cause:** Changing the parameterized array dimensions (`ARRAY_ROWS = 20`) without updating the fixed-width internal tracking registers. A 4-bit register maxes out at 15, causing the weight loading FSM to wrap around to 0 before loading the final rows of the array.
**Solution:** Dynamically sized the `write_row` register using `$clog2(ARRAY_ROWS)`.

## 3. Undriven LUT / Floating Input Optimization (Vivado `opt_design`)
**Error/Symptom:** Implementation `opt_design` failed with `[Opt 31-65] LUT input is undriven either due to a missing connection... LUT cell name: u_dvi2rgb/U0/DataDecoders[2].DecoderX/pAlignRst_i_1` and `WARNING: [Opt 31-155] Driverless net ... pRst is driving LUT input pin I1`.
**Root Cause:** The Digilent `dvi2rgb` IP core instantiated in `tinynpu_hdmi_top.v` had an optional active-high reset input port (`pRst`) that was left unconnected in the instantiation. Vivado optimization left the internal routing to this pin floating, breaking the logic deeper inside the IP.
**Solution:** Explicitly tied off all unused optional input ports on the IP core (e.g., `.pRst(1'b0)`, `.SDA_I(1'b1)`, `.SCL_I(1'b1)`). Never leave input ports floating on vendor IPs, even if they are marked optional.

## 4. Conflicting Directives in TCL Scripts
**Error/Symptom:** Vivado crashed immediately upon starting the `phys_opt_design` step with `ERROR: [Common 17-158] 'directive' can only be specified once.`
**Root Cause:** The `build_npu200j.tcl` script used a strategy preset (`Performance_ExplorePostRoutePhysOpt`) which inherently applies `-directive Explore`. The script then explicitly appended `-directive AggressiveExplore` to the `MORE OPTIONS` property, resulting in two conflicting directives passed to the tool.
**Solution:** Removed the manual `-directive` override from the TCL script, allowing the base strategy to govern the step. 

## 5. TCL Script Aborting on Expected Timing Failure
**Error/Symptom:** The Vivado build aborted with a custom TCL script error `Implementation FAILED` right after Routing finished, failing to generate a bitstream.
**Root Cause:** The script ran `wait_on_run impl_1` and then checked `if {[get_property PROGRESS [get_runs impl_1]] != "100%"}`. Because `route_design` failed timing requirements, the overall `impl_1` run state paused/aborted before the final bitstream step, so PROGRESS never hit 100%. 
**Solution:** Changed the TCL script to check `[string match "*Failed*" [get_property STATUS [get_runs impl_1]]]` instead of `PROGRESS`. Always use string matching on the STATUS property rather than checking for 100% progress when handling Vivado run objects.

## 6. Systolic Array Timing Closure Failure at 195 MHz
**Error/Symptom:** The post-route timing report showed a Worst Negative Slack (WNS) of **-1.825 ns** on the 195 MHz NPU clock domain (5.128 ns period). The critical path was located deep inside the `processing_element` DSP48 accumulation chain.
**Root Cause:** A 16x8 systolic array (128 MAC units) routing across the Zynq-7020 (-1 slow speed grade) experiences massive routing delay congestion. The 3-stage PE pipeline was not enough to mask the physical routing distances on the die.
**Solution:** Reduced the maximum clock frequency target from 195 MHz to **142.8 MHz** (7.000 ns period) by reconfiguring the MMCM dividers and XDC constraints. A 142.8 MHz clock still provides an aggressive ~18.2 GOPS throughput while ensuring clean routing and timing closure on cheap/slow -1 speed grade silicon.

## 7. MMCM/PLL VCO Limit Violation (DRC PDRC-34 / PDRC-43)
**Error/Symptom:** `write_bitstream` failed with `ERROR: [DRC PDRC-34] MMCM_adv_ClkFrequency_div_no_dclk: The computed value 571.429 MHz ... falls outside the operating range of the MMCM VCO frequency for this device (600.000 - 1200.000 MHz).`
**Root Cause:** When reducing the main NPU clock from 195 MHz to 142.857 MHz (to solve timing), the downstream `pixel_pll.v` MMCM (which synthesizes the 74.25 MHz HDMI clock) was still using its old multiplier (`8.0`) and divider values optimized for a 195 MHz input. A `142.857 * 8` VCO is only 571 MHz, which violates the Zynq-7020's 600 MHz physical hardware limit for PLL/MMCM VCOs.
**Solution:** Mathematically recalculated the MMCM parameters based on the new 142.857 MHz input. A multiplier of `7.000` yielded a clean 1000.0 MHz VCO, and a divider of `13.468` cleanly resulted in `74.250 MHz`, passing all DRC limits.

## 8. Digilent rgb2dvi / pynq_dvi_tx IP Clock Range Over-Multiplier
**Error/Symptom:** `write_bitstream` failed with `ERROR: [DRC PDRC-43] ... computed value 742.501 MHz ... falls outside the operating range of the PLL VCO frequency for this device (800.000 - 1600.000 MHz).` inside the `rgb2dvi` IP.
**Root Cause:** The Digilent HDMI TX IP uses an internal PLL to generate a 5x TMDS clock. By default, it expects an input clock of `>= 120 MHz` (`kClkRange` = 2), which internally multiplies by 10. When fed our 720p 74.25 MHz pixel clock, it multiplied by 10 resulting in a 742.5 MHz VCO—which violates the 800 MHz minimum hardware limit.
**Solution:** Updated the Vivado TCL IP generation script to explicitly set `CONFIG.kClkRange {2}` (`< 120 MHz`). This instructs the IP to use a 15x multiplier instead of 10x, resulting in a healthy 1113.75 MHz internal VCO.

## 9. XDC Parsing Failures Leading to Massive False Path Violations
**Error/Symptom:** The Vivado Timing Summary reported a colossal Worst Negative Slack (WNS) of -3.603 ns. Upon inspecting the timing report, the failing path was crossing between the 142.857 MHz NPU clock and the 74.25 MHz HDMI video clock domains, despite the presence of an Asynchronous FIFO (cdc_async_fifo.v).
**Root Cause:** In the constraints file (	inynpu_pynq200.xdc), the set_clock_groups -asynchronous command referenced a clock name clk_npu that was created using [get_ports clk]. However, the top-level wrapper did not have a port named clk (it was named sys_clk). Because the get_ports query failed, the create_clock command was ignored, which cascaded into the set_clock_groups command silently failing. Without the asynchronous clock group constraint, Vivado attempted to synchronously time the 142.8 MHz (7.0ns) domain against the 74.25 MHz (13.468ns) domain, resulting in an impossible fractional-nanosecond setup requirement.
**Solution:** Removed the invalid legacy create_clock commands and instead constrained the asynchronous clock groups using the exact clock net names auto-generated by the Vivado IPs.
**Takeaway:** Never trust a massively negative slack value without inspecting the From Clock and To Clock in the timing report! If they cross clock domains, verify your CDC constraints are actually parsing successfully.

## 10. Forcing Hold Slack (WHS) Closure in Vivado
**Error/Symptom:** After achieving positive Setup slack (WNS = 0.316 ns), the design still failed with a Worst Hold Slack (WHS) of -0.143 ns on intra-slice PE registers, leading to a Total Hold Slack (THS) violation.
**Root Cause:** Vivado's default Performance_Explore strategies strongly prioritize Setup slack (WNS). If Setup is met, the router sometimes doesn't try hard enough to detour data paths to fix microscopic hold time violations (clock skew) caused by high-fanout clock nets.
**Solution:** Do not try to fix this by lowering the clock frequency (hold slack is independent of clock frequency). Do not use AddRouting or ExploreWithHoldFix in the POST_ROUTE_PHYS_OPT_DESIGN stage (Vivado 2025.1 flags this as an invalid property). Instead, explicitly instruct the *Pre-Route* Physical Optimization stage to fix hold violations by inserting LUT-based delay buffers:
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE ExploreWithHoldFix [get_runs impl_1]
**Takeaway:** If WNS > 0 but WHS < 0, explicitly enable ExploreWithHoldFix during PHYS_OPT_DESIGN to force Vivado to physically buffer the fast data paths.
