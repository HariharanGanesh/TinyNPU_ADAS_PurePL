# Outputs Index

| Output File | Type | Version | Location | Description |
|---|---|---|---|---|
| `tinynpu.bit` | Bitstream | Current | `Build/pynq_deploy/` | Final FPGA bitstream |
| `final_timing_summary.txt` | Timing | Current | `Exports/timing/` | Final post-route setup/hold WNS=+0.033 |
| `final_critical_paths.txt` | Timing | Current | `Exports/timing/` | Detailed path analysis |
| `power_estimate.rpt` | Power | Current | `Build/synth_out/` | Vectorless power estimation |
| `utilization_impl.rpt` | Util | Current | `Build/synth_out/` | LUT/FF/BRAM/DSP usage |
| `tinynpu_sim.wdb` | Waveform | Current | `Exports/simulation/` | Simulation waveform DB |
| `tinynpu_top_routed.dcp` | Checkpoint | Current | `Build/synth_out/` | Routed design checkpoint |
