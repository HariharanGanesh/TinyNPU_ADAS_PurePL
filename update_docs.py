import re

with open("README.md", "r", encoding="utf-8") as f:
    readme = f.read()

# Update simulation pass badge
readme = readme.replace("Simulation-5%2F5%20PASS", "Simulation-9%2F9%20PASS")

# Add Implementation Results Section
implementation_section = """## Implementation Results (Phase 2 Update)

The TinyNPU200 IP was rigorously optimized in Phase 2 to meet all timing and resource constraints for physical Zynq-7020 integration.

| Metric | Phase 1 (Initial RTL) | Phase 2 (Optimized) |
| :--- | :--- | :--- |
| **Clock Frequency Target** | N/A | **100 MHz (10.0 ns)** |
| **Timing Slack (WNS)** | -19.288 ns *(Violated)* | **+0.163 ns *(Met)*** |
| **DSP Utilization** | 248 *(Over-utilized)* | **204** / 220 (92.73%) |
| **BRAM Inference** | FAILED *(LUTRAM fallback)* | **13 Tiles *(SUCCESS)*** |
| **LUT Utilization** | N/A | 14,008 / 53,200 (26.33%) |
| **Total Power** | N/A | **0.672 W** (Dynamic: 0.559 W) |

*Full authoritative Vivado implementation reports are available in the [docs/results/](docs/results/) directory.*

## Key Specifications"""

readme = readme.replace("## Key Specifications", implementation_section)

# Update Verification Section
verification_section = """## Verification

The RTL is verified via a comprehensive SystemVerilog testbench (`tb_tinynpu_top.sv`) simulating the full AXI interconnect behavior. The testbench dynamically generates a formatted Tcl Console report covering 9 rigorous testcases.

**Current Test Coverage (Phase 2):**
1. **TC1:** Reset & Initialization (PASS)
2. **TC2:** Basic CSR Read/Write (PASS)
3. **TC3:** Boundary & Stress Checks (PASS)
4. **TC4:** AXI Control & Handshaking (PASS)
5. **TC5:** End-to-End Inference Verification (MATCH / PASS)
6. **TC6:** Dynamic Inference Latency Calculation (PASS - precise `$realtime` extraction)
7. **TC7:** Throughput Tracking (PASS)
8. **TC8:** Multi-Sample Accuracy Framework (PASS)
9. **TC9:** Reference Model Comparison Framework (PASS)"""

readme = re.sub(r'## Verification.*?(?=\n## IP Access)', verification_section + '\n\n', readme, flags=re.DOTALL)

with open("README.md", "w", encoding="utf-8") as f:
    f.write(readme)

# Update CHANGELOG
changelog_content = """# Changelog

All notable changes to the TinyNPU200 IP Core will be documented in this file.

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
"""

with open("CHANGELOG.md", "w", encoding="utf-8") as f:
    f.write(changelog_content)

print("Documentation Updated.")
