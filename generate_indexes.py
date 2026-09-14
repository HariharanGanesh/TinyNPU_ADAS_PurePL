import os
import csv
import json

root = r"D:\Final year project"
repo_index = os.path.join(root, "Repository_Index")

if not os.path.exists(repo_index):
    os.makedirs(repo_index)

# FILE 1: INDEX.md
index_md = """# Repository Index

Welcome to the TinyNPU Project Repository. This index provides quick navigation to all important files and folders.

## 📂 Navigation Links

* [Folder Map](Folder_Map.md) - Complete directory tree
* [RTL Index](RTL_Index.md) - All Verilog/SystemVerilog source files
* [Testbench Index](Testbench_Index.md) - Verification environment and testbenches
* [Simulation Index](Simulation_Index.md) - Simulation scripts and outputs
* [Documents Index](Documents_Index.md) - PPTs, Posters, Reports, and References
* [Scripts Index](Scripts_Index.md) - Python, TCL, and Shell scripts
* [Vivado Index](Vivado_Index.md) - FPGA project files, block designs, and IPs
* [Cadence Index](Cadence_Index.md) - ASIC physical design (Empty for now)
* [Outputs Index](Outputs_Index.md) - Bitstreams, Timing/Power Reports, Checkpoints
* [Search Guide](Search_Guide.md) - Quick lookup table
* [Module Dependency Graph](module_dependency_graph.md) - RTL hierarchy

## 🏗️ Repository Structure

```text
D:/Final year project/
├── README.md
├── CHANGELOG.md
├── TinyNPU2050.bat
├── OPEN_VIVADO.bat
├── reorganize.ps1
├── Repository_Index/
├── Project_Documents/
│   ├── PPT/
│   ├── Reports/
│   ├── Posters/
│   ├── IEEE/
│   ├── References/
│   └── Diagrams/
├── Shared/
│   ├── Common/
│   ├── IP/
│   ├── Models/
│   └── Utilities/
├── Versions/
│   ├── tinyNPU2k/
│   ├── tinynpu_v3/
│   ├── TinyNPUIP2k/
│   └── tinynpu_pynq_system/
├── Build/
├── Vivado/
├── Cadence/
├── Exports/
├── Logs/
└── Temp/
```
"""
with open(os.path.join(repo_index, "INDEX.md"), "w", encoding="utf-8") as f:
    f.write(index_md)

# FILE 2: Folder_Map.md
folder_map_md = """# Folder Map

Complete directory tree of the repository.

```text
D:/Final year project/
├── README.md
├── CHANGELOG.md
├── TinyNPU2050.bat
├── OPEN_VIVADO.bat
├── reorganize.ps1
├── Build/
│   ├── pynq_deploy/
│   ├── synth_out/
│   └── tmp_ip_proj/
├── Cadence/
├── Exports/
│   ├── simulation/
│   └── timing/
├── Logs/
├── Project_Documents/
│   ├── Datasheets/
│   ├── Diagrams/
│   ├── IEEE/
│   ├── Meeting_Notes/
│   ├── Posters/
│   ├── PPT/
│   ├── Presentation_Notes/
│   ├── References/
│   └── Reports/
├── Repository_Index/
├── Shared/
│   ├── Common/
│   ├── Datasets/
│   ├── IP/
│   ├── Libraries/
│   ├── Models/
│   └── Utilities/
├── Temp/
├── Unsorted/
├── Versions/
│   ├── tinyNPU2k/
│   ├── TinyNPUIP2k/
│   ├── tinynpu_pynq_system/
│   └── tinynpu_v3/
└── Vivado/
    ├── scripts/
    └── vivado_system_backup/
```
"""
with open(os.path.join(repo_index, "Folder_Map.md"), "w", encoding="utf-8") as f:
    f.write(folder_map_md)

# FILE 3: RTL_Index.md
rtl_index_md = """# RTL Index

| Filename | Module Name | Relative Path | Version | Description |
|---|---|---|---|---|
| `activation_unit.v` | activation_unit | `rtl/activation/` | tinynpu_pynq_system | Top wrapper for nonlinear activation |
| `piecewise_sigmoid.v` | piecewise_sigmoid | `rtl/activation/` | tinynpu_pynq_system | Combinational piecewise sigmoid approx |
| `sigmoid_lut.v` | sigmoid_lut | `rtl/activation/` | tinynpu_pynq_system | BRAM-based Sigmoid LUT for INT8 |
| `axi4_lite_slave.v` | axi4_lite_slave | `rtl/axi/` | tinynpu_pynq_system | Control plane register interface |
| `axis_sink.v` | axis_sink | `rtl/axi/` | tinynpu_pynq_system | AXI-Stream receiver for input activations |
| `axis_source.v` | axis_source | `rtl/axi/` | tinynpu_pynq_system | AXI-Stream transmitter for outputs |
| `activation_buffer.v` | activation_buffer | `rtl/buffers/` | tinynpu_pynq_system | Ping-pong buffers for activations |
| `output_buffer.v` | output_buffer | `rtl/buffers/` | tinynpu_pynq_system | Ping-pong buffers for PE outputs |
| `weight_buffer.v` | weight_buffer | `rtl/buffers/` | tinynpu_pynq_system | Buffers for stationary weights |
| `clk_gate_bufgce.v` | clk_gate_bufgce | `rtl/clocking/` | tinynpu_pynq_system | FPGA-specific ICG mapping (BUFGCE) |
| `npu_controller.v` | npu_controller | `rtl/control/` | tinynpu_pynq_system | Main FSM orchestrating dataflow |
| `rst_sync.v` | rst_sync | `rtl/core/` | tinynpu_pynq_system | Asynchronous reset synchronizer |
| `sram_1rw.v` | sram_1rw | `rtl/core/` | tinynpu_pynq_system | Single-port SRAM wrapper |
| `sram_2rw.v` | sram_2rw | `rtl/core/` | tinynpu_pynq_system | Dual-port SRAM wrapper |
| `tinynpu_icg.v` | tinynpu_icg | `rtl/core/` | tinynpu_pynq_system | Integrated clock gating cell |
| `dma_controller.v` | dma_controller | `rtl/dma/` | tinynpu_pynq_system | Manages internal data movement |
| `dw_line_buffer.v` | dw_line_buffer | `rtl/dw_engine/` | tinynpu_pynq_system | Line buffers for depthwise conv |
| `frame_gen.v` | frame_gen | `rtl/frontend/` | tinynpu_pynq_system | Sensor frame generation |
| `pl_top.v` | pl_top | `rtl/frontend/` | tinynpu_pynq_system | PL domain top wrapper |
| `result_capture.v` | result_capture | `rtl/frontend/` | tinynpu_pynq_system | Inference result capture logic |
| `bbox_decoder.v` | bbox_decoder | `rtl/pe/` | tinynpu_pynq_system | Bounding box coordinate decoding |
| `processing_element.v` | processing_element | `rtl/pe/` | tinynpu_pynq_system | Multiply-Accumulate unit |
| `pooling_unit.v` | pooling_unit | `rtl/pooling/` | tinynpu_pynq_system | Max pooling implementation |
| `requantization_unit.v` | requantization_unit | `rtl/quantization/` | tinynpu_pynq_system | INT32 to INT8 downscaling |
| `threshold_filter.v` | threshold_filter | `rtl/quantization/` | tinynpu_pynq_system | Output thresholding for confidence |
| `systolic_array.v` | systolic_array | `rtl/systolic_array/` | tinynpu_pynq_system | 8x8 weight-stationary MAC array |
| `tinynpu_top.v` | tinynpu_top | `rtl/top/` | tinynpu_pynq_system | Core IP top level module |
| `tinynpu_asic_wrapper.v` | tinynpu_asic_wrapper | `rtl/wrappers/asic/` | tinynpu_pynq_system | ASIC specific instantiation wrapper |
| `tinynpu_fpga_wrapper.v` | tinynpu_fpga_wrapper | `rtl/wrappers/fpga/` | tinynpu_pynq_system | FPGA specific instantiation wrapper |
"""
with open(os.path.join(repo_index, "RTL_Index.md"), "w", encoding="utf-8") as f:
    f.write(rtl_index_md)

# FILE 4: Testbench_Index.md
tb_index_md = """# Testbench Index

| Testbench File | RTL Module It Tests | Language | Location |
|---|---|---|---|
| `tinynpu_top_tb.sv` | `tinynpu_top` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `tinynpu_system_tb.sv` | Full System | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `systolic_array_tb.sv` | `systolic_array` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `dw_line_buffer_tb.sv` | `dw_line_buffer` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `bbox_decoder_tb.sv` | `bbox_decoder` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `pe_assertions.sv` | `processing_element` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `tinynpu_assertions.sv` | `tinynpu_top` | SystemVerilog | `Versions/tinynpu_pynq_system/testbench/` |
| `hw_scoreboard.v` | General Check | Verilog | `Versions/tinynpu_pynq_system/testbench/` |
| `perf_monitor.v` | General Monitor | Verilog | `Versions/tinynpu_pynq_system/testbench/` |
"""
with open(os.path.join(repo_index, "Testbench_Index.md"), "w", encoding="utf-8") as f:
    f.write(tb_index_md)

# FILE 5: Simulation_Index.md
sim_index_md = """# Simulation Index

## Scripts
* `Shared/Utilities/run_sim.ps1` - Main simulation runner
* `Versions/tinynpu_pynq_system/simulation/run_top_sim.ps1` - Top module simulation runner

## Waveforms
* `Exports/simulation/tinynpu_sim.wdb` - Vivado simulation waveform database

## Test Vectors (in `Versions/tinynpu_pynq_system/testbench/vectors/`)
* `tc1_act_stream.txt`
* `tc1_cfg.txt`
* `tc1_expected_out.txt`
* `tc1_wgt_mem.txt`
* `golden_output.hex`
* `sigmoid_lut_init.hex`
* `test_sensor_data.hex`
* `dfx_runtime.txt`
"""
with open(os.path.join(repo_index, "Simulation_Index.md"), "w", encoding="utf-8") as f:
    f.write(sim_index_md)

# FILE 6: Documents_Index.md
doc_index_md = """# Documents Index

| Document | Type | Description | Location |
|---|---|---|---|
| `TinyNPU_Presentation.pptx` | PPT | Main project presentation | `Project_Documents/PPT/` |
| `TinyNPU_Zeroth_Review.pptx` | PPT | Initial review slides | `Project_Documents/PPT/` |
| `TinyNPU_Zeroth_Review_v3.pptx` | PPT | Updated review slides | `Project_Documents/PPT/` |
| `TinyNPU_IEEE_Poster.pdf` | Poster | IEEE format poster | `Project_Documents/IEEE/` |
| `TinyNPU_IEEE_Poster_v4.pdf` | Poster | IEEE format poster final | `Project_Documents/IEEE/` |
| `TinyNPU_Poster.pdf` | Poster | General project poster | `Project_Documents/Posters/` |
| `TinyNPU_Study_Guide.md` | Report | Study guide for mentor | `Project_Documents/Reports/` |
| `ADR_log.md` | Report | Architectural Decision Records | `Project_Documents/Reports/` |
| `tinynpu_asic_architecture.md` | Report | ASIC migration architecture | `Project_Documents/Reports/` |
| `literature_review.md` | Reference | Literature survey | `Project_Documents/References/` |
"""
with open(os.path.join(repo_index, "Documents_Index.md"), "w", encoding="utf-8") as f:
    f.write(doc_index_md)

# FILE 7: Scripts_Index.md
scripts_index_md = """# Scripts Index

| Script Name | Type | Purpose | Location |
|---|---|---|---|
| `definitive_rebuild.tcl` | TCL | Automated rebuild | `Vivado/scripts/` |
| `final_close_0p176.tcl` | TCL | Timing closure adjustments | `Vivado/scripts/` |
| `final_rebuild.tcl` | TCL | Final rebuild | `Vivado/scripts/` |
| `run_final_rebuild.tcl` | TCL | Run final rebuild | `Vivado/scripts/` |
| `run_final_rebuild_v2.tcl` | TCL | Run final rebuild v2 | `Vivado/scripts/` |
| `run_final_rebuild_v3.tcl` | TCL | Run final rebuild v3 | `Vivado/scripts/` |
| `rebuild_all.tcl` | TCL | Clean rebuild all | `Vivado/scripts/` |
| `upgrade_and_build.tcl` | TCL | Upgrade IP and build | `Vivado/scripts/` |
| `force_resynth_tinynpu.tcl` | TCL | Force IP re-synthesis | `Vivado/scripts/` |
| `synth.tcl` | TCL | Synthesis script | `Vivado/scripts/` |
| `synth_impl.tcl` | TCL | Implementation script | `Vivado/scripts/` |
| `build_tinynpu2k.tcl` | TCL | Build old version | `Vivado/scripts/` |
| `gen_patch_rebuild.tcl` | TCL | Cache-busting rebuild | `Vivado/scripts/` |
| `package_ip.tcl` | TCL | Package IP into repo | `Vivado/scripts/` |
| `build_pynq_system.tcl` | TCL | Build PL system | `Vivado/scripts/` |
| `update_to_pl_frontend.tcl` | TCL | Update block design | `Vivado/scripts/` |
| `export_hw.tcl` | TCL | Export XSA | `Vivado/scripts/` |
| `open_vivado_project.tcl` | TCL | Project opener | `Vivado/scripts/` |
| `close_timing.tcl` | TCL | Timing closure strategies | `Vivado/scripts/` |
| `optimize_100mhz.tcl` | TCL | 100MHz target optimization | `Vivado/scripts/` |
| `fix_io.tcl` | TCL | I/O constraint fix | `Vivado/scripts/` |
| `fix_timing.tcl` | TCL | General timing fixes | `Vivado/scripts/` |
| `fix_xdc_conflict.tcl` | TCL | XDC conflict resolution | `Vivado/scripts/` |
| `batch_phys_opt.tcl` | TCL | Physical optimization | `Vivado/scripts/` |
| `run_sim.ps1` | PS1 | Run simulation | `Shared/Utilities/` |
| `update.py` | Python | Project updater | `Shared/Utilities/` |
"""
with open(os.path.join(repo_index, "Scripts_Index.md"), "w", encoding="utf-8") as f:
    f.write(scripts_index_md)

# FILE 8: Vivado_Index.md
vivado_index_md = """# Vivado Index

| Item | Type | Version | Location | Notes |
|---|---|---|---|---|
| `tinynpu_pynq_system` | `.xpr` dir | Current | `Vivado/tinynpu_pynq_system_project/` | Active development project |
| `tinynpu_v3.xpr` | `.xpr` | Version 2 | `Versions/tinynpu_v3/configs/` | Archival |
| `tinyNPU2k.xpr` | `.xpr` | Version 1 | `Versions/tinyNPU2k/configs/` | Archival |
| `tinynpu` | IP Core | Version 2.1 | `Shared/IP/ip_repo/` | Packaged IP ready for BD |
| `tinynpu.bit` | Bitstream | Current | `Build/pynq_deploy/` | Bitstream (WNS +0.033ns) |
| `tinynpu_top.dcp` | Checkpoint | Current | `Build/synth_out/` | Post-synthesis DCP |
| `tinynpu_top_routed.dcp` | Checkpoint | Current | `Build/synth_out/` | Post-route DCP |
| `tinynpu_pynq.xdc` | Constraints| Current | `Shared/Common/` | PYNQ-Z2 Constraints |
| `tinynpu.xdc` | Constraints| Current | `Shared/Common/` | Timing Constraints |
"""
with open(os.path.join(repo_index, "Vivado_Index.md"), "w", encoding="utf-8") as f:
    f.write(vivado_index_md)

# FILE 9: Cadence_Index.md
cadence_index_md = """# Cadence Index

*Note: This project is currently FPGA-only targeting Xilinx Zynq-7020.*

For future ASIC tape-out, this directory will contain:
- `Genus` (Synthesis scripts and logs)
- `Innovus` (Place and Route)
- `Tempus` (Static Timing Analysis)
- `Voltus` (Power Signoff)
- `Liberty` (.lib files)
- `LEF` / `DEF` / `GDS` (Physical design exports)
- `SDC` (ASIC constraints)
"""
with open(os.path.join(repo_index, "Cadence_Index.md"), "w", encoding="utf-8") as f:
    f.write(cadence_index_md)

# FILE 10: Outputs_Index.md
outputs_index_md = """# Outputs Index

| Output File | Type | Version | Location | Description |
|---|---|---|---|---|
| `tinynpu.bit` | Bitstream | Current | `Build/pynq_deploy/` | Final FPGA bitstream |
| `final_timing_summary.txt` | Timing | Current | `Exports/timing/` | Final post-route setup/hold WNS=+0.033 |
| `final_critical_paths.txt` | Timing | Current | `Exports/timing/` | Detailed path analysis |
| `power_estimate.rpt` | Power | Current | `Build/synth_out/` | Vectorless power estimation |
| `utilization_impl.rpt` | Util | Current | `Build/synth_out/` | LUT/FF/BRAM/DSP usage |
| `tinynpu_sim.wdb` | Waveform | Current | `Exports/simulation/` | Simulation waveform DB |
| `tinynpu_top_routed.dcp` | Checkpoint | Current | `Build/synth_out/` | Routed design checkpoint |
"""
with open(os.path.join(repo_index, "Outputs_Index.md"), "w", encoding="utf-8") as f:
    f.write(outputs_index_md)

# FILE 11: Search_Guide.md
search_guide_md = """# Search Guide

Quick lookup table:

| If I need... | Go Here |
|---|---|
| Top module (`tinynpu_top.v`) | `Shared/Common/01_RTL/top/` or `Versions/tinynpu_pynq_system/rtl/src/top/` |
| Systolic Array | `Versions/tinynpu_pynq_system/rtl/src/systolic_array/` |
| Processing Element | `Versions/tinynpu_pynq_system/rtl/src/pe/` |
| AXI slave | `Versions/tinynpu_pynq_system/rtl/src/axi/` |
| DMA | `Versions/tinynpu_pynq_system/rtl/src/dma/` |
| Clock Gate (ICG) | `Versions/tinynpu_pynq_system/rtl/src/clocking/` and `core/` |
| Weight Buffer | `Versions/tinynpu_pynq_system/rtl/src/buffers/` |
| Activation Buffer | `Versions/tinynpu_pynq_system/rtl/src/buffers/` |
| Requantization | `Versions/tinynpu_pynq_system/rtl/src/quantization/` |
| Sigmoid LUT | `Versions/tinynpu_pynq_system/rtl/src/activation/` |
| Testbench | `Versions/tinynpu_pynq_system/testbench/` |
| Simulation scripts | `Versions/tinynpu_pynq_system/simulation/` |
| Constraints | `Versions/tinynpu_pynq_system/constraints/` |
| Vivado Project (current) | `Vivado/tinynpu_pynq_system_project/` |
| Vivado Project (v3) | `Versions/tinynpu_v3/configs/` |
| Vivado Project (v2k) | `Versions/tinyNPU2k/configs/` |
| TCL Scripts | `Vivado/scripts/` |
| Bitstream (`.bit`) | `Build/pynq_deploy/` and `Versions/tinynpu_pynq_system/outputs/bitstream/` |
| Timing Report | `Exports/timing/` and `Versions/tinynpu_pynq_system/outputs/timing/` |
| Power Report | `Versions/tinynpu_pynq_system/outputs/power/` |
| Utilization Report | `Versions/tinynpu_pynq_system/outputs/utilization/` |
| PPT / Presentation | `Project_Documents/PPT/` |
| Poster | `Project_Documents/Posters/` and `Project_Documents/IEEE/` |
| Paper / References | `Project_Documents/References/` |
| Python Model | `Shared/Models/` |
| IP Core | `Shared/IP/ip_repo/` and `Versions/TinyNPUIP2k/` |
| Latest Stable Version | `Versions/tinynpu_pynq_system/` (WNS=+0.033ns, 100MHz CLOSED) |
"""
with open(os.path.join(repo_index, "Search_Guide.md"), "w", encoding="utf-8") as f:
    f.write(search_guide_md)

# FILE 12: module_dependency_graph.md
graph_md = """# Module Dependency Graph

```mermaid
graph TD
    top[tinynpu_top]
    axi_s[axi4_lite_slave]
    ctrl[npu_controller]
    dma[dma_controller]
    sys_arr[systolic_array]
    act_buf[activation_buffer]
    wgt_buf[weight_buffer]
    out_buf[output_buffer]
    act_unit[activation_unit]
    req[requantization_unit]
    thresh[threshold_filter]
    pool[pooling_unit]
    icg[tinynpu_icg]
    rst[rst_sync]

    top --> axi_s
    top --> ctrl
    top --> dma
    top --> sys_arr
    top --> act_buf
    top --> wgt_buf
    top --> out_buf
    top --> act_unit
    top --> req
    top --> thresh
    top --> pool
    top --> icg
    top --> rst

    sys_arr --> pe[processing_element]
    pe --> bbox[bbox_decoder]
    
    act_unit --> sig_lut[sigmoid_lut]
    act_unit --> p_sig[piecewise_sigmoid]

    ctrl --> act_buf
    ctrl --> wgt_buf
    ctrl --> dma
```
"""
with open(os.path.join(repo_index, "module_dependency_graph.md"), "w", encoding="utf-8") as f:
    f.write(graph_md)

# DATA for CSV/JSON
files_data = [
    {"Filename": "tinynpu_top.v", "Extension": ".v", "Category": "RTL", "ProjectVersion": "Current", "RelativePath": "rtl/top/", "Description": "Top module"},
    {"Filename": "systolic_array.v", "Extension": ".v", "Category": "RTL", "ProjectVersion": "Current", "RelativePath": "rtl/systolic_array/", "Description": "MAC Array"},
    {"Filename": "tinynpu_top_tb.sv", "Extension": ".sv", "Category": "Testbench", "ProjectVersion": "Current", "RelativePath": "Versions/tinynpu_pynq_system/testbench/", "Description": "Top TB"},
    {"Filename": "tinynpu.bit", "Extension": ".bit", "Category": "Bitstream", "ProjectVersion": "Current", "RelativePath": "Build/pynq_deploy/", "Description": "FPGA Bitstream"},
    {"Filename": "final_timing_summary.txt", "Extension": ".txt", "Category": "Report", "ProjectVersion": "Current", "RelativePath": "Exports/timing/", "Description": "Timing Report"},
    {"Filename": "TinyNPU_Presentation.pptx", "Extension": ".pptx", "Category": "Document", "ProjectVersion": "All", "RelativePath": "Project_Documents/PPT/", "Description": "Presentation"},
    {"Filename": "TinyNPU_IEEE_Poster.pdf", "Extension": ".pdf", "Category": "Document", "ProjectVersion": "All", "RelativePath": "Project_Documents/IEEE/", "Description": "Poster"},
    {"Filename": "build_pynq_system.tcl", "Extension": ".tcl", "Category": "Script", "ProjectVersion": "Current", "RelativePath": "Vivado/scripts/", "Description": "Vivado build script"},
    {"Filename": "run_sim.ps1", "Extension": ".ps1", "Category": "Script", "ProjectVersion": "Current", "RelativePath": "Shared/Utilities/", "Description": "Sim script"},
    {"Filename": "tinynpu_icg.v", "Extension": ".v", "Category": "RTL", "ProjectVersion": "Current", "RelativePath": "rtl/core/", "Description": "Clock gate"},
    {"Filename": "tinynpu_pynq_system.xpr", "Extension": ".xpr", "Category": "Vivado", "ProjectVersion": "Current", "RelativePath": "Vivado/tinynpu_pynq_system_project/", "Description": "Active project"},
]

# FILE 13: file_index.csv
csv_path = os.path.join(repo_index, "file_index.csv")
with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["Filename", "Extension", "Category", "ProjectVersion", "RelativePath", "Description"])
    writer.writeheader()
    for row in files_data:
        writer.writerow(row)

# FILE 14: file_index.json
json_path = os.path.join(repo_index, "file_index.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(files_data, f, indent=4)

# Create CHANGELOG.md at root
changelog = """# Changelog

## Current (tinynpu_pynq_system)
- Fully closed timing at 100MHz (WNS=+0.033ns)
- Fixed clock skew (-3.35ns) by routing `threshold_filter` to `clk_postproc`
- Implemented pipelined comparison in `frame_gen` (resolved -1.285ns path)
- Built automated TCL scripts for cache-busting Vivado `.gen` directory

## Version 3 (tinynpu_v3)
- Experimental design iterations.

## Version 2 (TinyNPUIP2k)
- Packaged RTL into a Vivado IP core for Block Design usage.

## Version 1 (tinyNPU2k)
- Initial naive implementation and project setup.
"""
with open(os.path.join(root, "CHANGELOG.md"), "w", encoding="utf-8") as f:
    f.write(changelog)

print("All index files generated successfully.")
