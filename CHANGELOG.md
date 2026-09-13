# Changelog

All notable changes to the TinyNPU_ADAS_PurePL IP Core will be documented in this file.

## [v2.0.0] - Phase 2 Major Optimization Update
### Improved
- **DSP Utilization:** Slashed from 248 to 204 DSPs by migrating `SCALE_WIDTH` and pipelining top-level combinational chains. The design now perfectly fits the Zynq-7020 constraints (220 limit).
- **Timing Closure (WNS):** Achieved fully constrained positive slack (+0.163 ns) at 100 MHz on the Zynq-7020 by breaking critical paths into a 3-stage `use_dsp` pipeline.
- **BRAM Inference:** Re-architected memory mapping in `weight_buffer.v` and `activation_buffer.v` from disjoint conditionally-accessed arrays into unified arrays. Successfully resolved all LUTRAM fallback inference warnings to achieve pristine Block RAM mapping (13 Tiles).

### Added
- **`ooc_timing.xdc`:** Out-Of-Context design constraint targeting 100 MHz (10.0 ns) for accurate post-route analysis.
- **Verification Report:** Completely rewrote `tb_tinynpu_top.sv` to run 9 detailed testcases (TC1-TC9), featuring `$realtime` nanosecond extraction for latency and automated TCL console validation reporting.
- **Implementation Results:** Published final Phase 2 Power (0.672 W) and Utilization metrics under `docs/results/`.

## [v1.0.0] - Initial Release
### Added
- Initial weight-stationary systolic array architecture (20x8).
- AXI4-Lite CSR integration.
- AXI4 Master DMA for autonomous weight loading and output storage.
- First functional simulation verification setup.
- Initial IP documentation and terms of use.
