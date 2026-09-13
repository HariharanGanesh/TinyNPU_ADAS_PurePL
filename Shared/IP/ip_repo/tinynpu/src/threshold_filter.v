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

    // Pipeline stage for input data and valid signal
    reg [DATA_WIDTH*NUM_COLS-1:0] data_in_reg;
    reg                           valid_in_reg;
    reg                           pass_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            data_in_reg  <= 0;
            valid_in_reg <= 1'b0;
            pass_reg     <= 1'b0;
        end else begin
            data_in_reg  <= data_in_flat;
            valid_in_reg <= valid_in;
            // Calculate pass condition in the first cycle
            // Extract the first channel (col 0) as the score byte for comparison
            pass_reg     <= (!filter_en) || ($unsigned(data_in_flat[DATA_WIDTH-1:0]) >= $unsigned(conf_threshold));
        end
    end

    // Second pipeline stage: conditionally output data based on pass_reg
    always @(posedge clk) begin
        if (!rst_n) begin
            data_out_flat <= 0;
            valid_out     <= 1'b0;
        end else begin
            if (valid_in_reg && pass_reg) begin
                data_out_flat <= data_in_reg;
                valid_out     <= 1'b1;
            end else begin
                data_out_flat <= 0;
                valid_out     <= 1'b0;
            end
        end
    end

endmodule
