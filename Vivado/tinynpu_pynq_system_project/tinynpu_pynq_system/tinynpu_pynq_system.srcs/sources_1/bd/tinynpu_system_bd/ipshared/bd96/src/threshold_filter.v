// =============================================================================
// Module: threshold_filter.v
// Project: TinyNPU
// Description:
//   Hardware Confidence Score Threshold Filter.
//
//   PURPOSE:
//   Face detection and object detection models produce thousands of candidate
//   bounding boxes, most with very low confidence. Passing all of them to the
//   ARM processor wastes AXI-Stream bandwidth and CPU cycles.
//   This filter drops any output beat whose score byte is below the configured
//   threshold, preventing it from being written to the output FIFO.
//
//   OPERATION:
//   - Takes 8-bit quantized activations from the activation unit output.
//   - When the first byte of each TILE_SIZE-byte output packet arrives, it is
//     compared against csr_conf_threshold.
//   - If score < threshold, the entire packet's wr_en is suppressed.
//   - If score >= threshold, all bytes in the packet pass through to output FIFO.
//
//   For plain feature map output (non-detection layers), set threshold to 0
//   to disable filtering.
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module threshold_filter #(
    parameter DATA_WIDTH  = 8,
    parameter NUM_COLS    = 8   // Bytes per output cycle (one row of systolic array)
) (
    input  wire                          clk,
    input  wire                          rst_n,

    // Input from Activation Unit / Pooling Unit
    input  wire [DATA_WIDTH*NUM_COLS-1:0] data_in_flat,
    input  wire                           valid_in,

    // Confidence threshold configuration
    input  wire [DATA_WIDTH-1:0]          conf_threshold,
    // When filter_en=0, all samples pass through (bypass mode for feature layers)
    input  wire                           filter_en,

    // Output to Output Buffer FIFO
    output reg  [DATA_WIDTH*NUM_COLS-1:0] data_out_flat,
    output reg                            valid_out
);

    // Extract the first channel (col 0) as the score byte for comparison
    wire [DATA_WIDTH-1:0] score_byte = data_in_flat[DATA_WIDTH-1:0];

    // Pass when filtering is disabled OR when score meets threshold
    wire pass = (!filter_en) || ($unsigned(score_byte) >= $unsigned(conf_threshold));

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out_flat <= 0;
            valid_out     <= 1'b0;
        end else begin
            if (valid_in && pass) begin
                data_out_flat <= data_in_flat;
                valid_out     <= 1'b1;
            end else begin
                data_out_flat <= 0;
                valid_out     <= 1'b0;
            end
        end
    end

endmodule
