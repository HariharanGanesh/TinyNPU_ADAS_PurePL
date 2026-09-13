# Changelog

All notable changes to **TinyNPU_ADAS_PurePL** are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v2.1.0] — 2026-09-13 · Repository Professionalization

### Added
- `constraints/` folder: all XDC files moved from root into a dedicated directory.
- `firmware/` folder: RISC-V baremetal firmware and header files.
- `scripts/` folder: setup and toolchain automation scripts.
- `docs/` folder: consolidated technical documentation.
- Complete redesigned `README.md` with architecture diagram, resource tables, test results, and build guide.
- Full governance suite: `CHANGELOG.md`, `CONTRIBUTING.md`, `ACCESS.md`, `TERMS_OF_USE.md`.

### Removed
- Root-level build debris: `audit_out.txt`, `clockInfo.txt`, `diff.txt`, `tb.txt`, `tb_backup.txt`, `timing_report.txt`, `util_report.txt`, `Add Repository`.
- `ORGANIZATION_REPORT.md` (stale script output).
- All loose automation `.tcl`, `.bat`, and `.py` files from repository root.

---

## [v2.0.0] — 2026-09-13 · Pure PL Implementation Complete

### Added
- `RISCV_ADAS_PURE_PL/` Vivado project: full pure-PL Block Design targeting PYNQ-Z2.
- `npu_system.bd`: Block Design integrating TinyNPU200, HDMI PHYs (RGB2DVI / DVI2RGB), Clock Wizard (MMCM), Video Timing Controller (VTC), and JTAG-AXI debug bridge.
- `pynq_z2_customized.xdc`: PYNQ-Z2 pin mappings for ADAS GPIO (LEDs, switches).
- `drc_bypass.xdc`: Waiver for Digilent DVI2RGB OOC DRC trimming issue (NDRV-1).
- `clock_bypass.xdc`: `CLOCK_DEDICATED_ROUTE FALSE` fix for BUFG-BUFG cascade.

### Fixed
- **NSTD-1 / UCIO-1 DRC failures** during `write_bitstream`: fixed by correctly mapping all `npu_system_wrapper` top-level ADAS output ports (`out_warning_lane`, `out_warning_ped`, `out_warning_sign`, `out_brake_authorized`, `out_system_fault`, `sw_brake_arm`) to physical PYNQ-Z2 pins.
- **BUFG-BUFG cascade placement failure**: resolved via `CLOCK_DEDICATED_ROUTE FALSE` on the PS7 `FCLK_CLK0` net.

### Results
- 30,572 internal nets fully routed — 0 overlaps.
- Timing met: 125 MHz NPU datapath, 200 MHz HDMI Video PHY.
- Bitstream successfully generated: `npu_system_wrapper.bit` (~4 MB).

---

## [v1.1.0] — 2026-08-20 · ADAS Detection Head Integration

### Added
- `npu_detection_head.v`: top-level integration wrapper for the full ADAS pipeline.
- `streaming_topk.v`: streaming hardware Top-K confidence extractor.
- `bbox_decoder_dfl.v`: 4× parallel Distributed Focal Loss (DFL) bounding box decoder.
- `sparse_candidate_packer.v`: 128-bit ADAS memory record assembler with BRAM write.
- `sigmoid_lut.v`: 256-entry BRAM-based sigmoid LUT (2-cycle latency).
- `piecewise_sigmoid.v`: Zero-BRAM combinational sigmoid approximation (ASIC-ready).
- SystemVerilog testbenches for all four pipeline modules.
- Verification summaries under `verification/reports/summaries/`.

### Verified
- POV 10 (Integration): injected 200 INT8 class logits → correctly decoded 128-bit ADAS record. Zero bugs.

---

## [v1.0.0] — 2026-08-13 · Initial TinyNPU200 IP Core Release

### Added
- `tinynpu_top.v`: weight-stationary 20×8 systolic array NPU, synthesizable Verilog-2001.
- AXI4-Lite CSR integration (strict handshake compliance).
- AXI4 DMA master for autonomous weight loading.
- AXI4-Stream sink/source for activation streaming.
- 5-test SystemVerilog testbench (`tb_tinynpu_top.sv`) — all tests pass.
- IP packaged for Vivado IP Catalog (`IP/TinyNPU200/component.xml`).
- Initial documentation and IP terms of use.
