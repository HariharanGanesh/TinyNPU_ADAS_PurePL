# RTL Index

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
