// =============================================================================
// Module: bbox_decoder.v
// Project: TinyNPU
// Description:
//   YOLOv8-Native Bounding Box Decoder (Anchor-Free / DFL).
//
//   MATHEMATICAL BACKGROUND:
//   Unlike YOLOv2/v3 which used anchors and exponential scaling, YOLOv8
//   predicts distances from the cell center to the left, top, right, and
//   bottom boundaries (l, t, r, b).
//
//   Absolute Box Coordinates:
//     cx = (grid_x + 0.5) * stride
//     cy = (grid_y + 0.5) * stride
//     x1 = cx - (l * stride)
//     y1 = cy - (t * stride)
//     x2 = cx + (r * stride)
//     y2 = cy + (b * stride)
//
//   Confidence/Class Scores:
//     score = sigmoid(raw_score)
//
//   This module implements a fully combinational/low-latency pipeline for
//   these operations, entirely eliminating DSP-heavy exponential math.
//   It utilizes the `piecewise_sigmoid` IP for the confidence decoding.
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module bbox_decoder #(
    parameter DATA_WIDTH   = 8,   // Input INT8 offsets
    parameter COORD_WIDTH  = 16   // Output absolute coordinate width
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Raw detection distances from YOLOv8 head (INT8 quantized, treated as unsigned distance)
    input  wire [DATA_WIDTH-1:0]    dist_l_in,
    input  wire [DATA_WIDTH-1:0]    dist_t_in,
    input  wire [DATA_WIDTH-1:0]    dist_r_in,
    input  wire [DATA_WIDTH-1:0]    dist_b_in,
    
    // Raw confidence score
    input  wire [DATA_WIDTH-1:0]    conf_in,

    // Current Grid Cell (e.g. from a coordinate counter tracking output stream)
    input  wire [COORD_WIDTH-1:0]   grid_x,
    input  wire [COORD_WIDTH-1:0]   grid_y,

    // Grid stride (pixels per grid cell, e.g. 32 for 32px stride)
    input  wire [7:0]               grid_stride,

    // Frame boundary (used to clip decoded boxes)
    input  wire [COORD_WIDTH-1:0]   frame_w,
    input  wire [COORD_WIDTH-1:0]   frame_h,

    // Pipeline Control
    input  wire                     valid_in,
    output reg                      valid_out,

    // Decoded absolute coordinates (pixel space, clipped to frame bounds)
    output reg  [COORD_WIDTH-1:0]   bbox_x1,
    output reg  [COORD_WIDTH-1:0]   bbox_y1,
    output reg  [COORD_WIDTH-1:0]   bbox_x2,
    output reg  [COORD_WIDTH-1:0]   bbox_y2,
    
    // Decoded Confidence score (0..255)
    output wire [DATA_WIDTH-1:0]    conf_out
);

    // =========================================================================
    // Combinational Sigmoid for Confidence Score
    // =========================================================================
    // The piecewise_sigmoid module maps an INT8 raw confidence to a UINT8
    // probability (0-255).
    piecewise_sigmoid u_sigmoid_conf (
        .x_in(conf_in),
        .sigmoid_out(conf_out)
    );

    // =========================================================================
    // Stage 1: Compute Center Pixel & Distance Conversions (1 cycle)
    // =========================================================================
    reg [COORD_WIDTH-1:0] cx, cy;
    reg [COORD_WIDTH-1:0] px_l, px_t, px_r, px_b;
    reg                   stage1_valid;
    
    // Stride half = stride >> 1
    wire [7:0] stride_half = grid_stride >> 1;

    always @(posedge clk) begin
        if (!rst_n) begin
            cx <= 0; cy <= 0;
            px_l <= 0; px_t <= 0; px_r <= 0; px_b <= 0;
            stage1_valid <= 1'b0;
        end else begin
            stage1_valid <= valid_in;
            
            // cx = (grid_x * stride) + (stride/2)
            cx <= (grid_x * grid_stride) + stride_half;
            cy <= (grid_y * grid_stride) + stride_half;
            
            // Multiply distances by stride
            px_l <= dist_l_in * grid_stride;
            px_t <= dist_t_in * grid_stride;
            px_r <= dist_r_in * grid_stride;
            px_b <= dist_b_in * grid_stride;
        end
    end

    // =========================================================================
    // Stage 2: Compute Absolute Coordinates & Clip to Frame (1 cycle)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            bbox_x1   <= 0;
            bbox_y1   <= 0;
            bbox_x2   <= 0;
            bbox_y2   <= 0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= stage1_valid;

            // x1 = max(0, cx - px_l)
            if (cx >= px_l) bbox_x1 <= cx - px_l;
            else            bbox_x1 <= 0;

            // y1 = max(0, cy - px_t)
            if (cy >= px_t) bbox_y1 <= cy - px_t;
            else            bbox_y1 <= 0;

            // x2 = min(frame_w, cx + px_r)
            if ((cx + px_r) <= frame_w) bbox_x2 <= cx + px_r;
            else                        bbox_x2 <= frame_w;

            // y2 = min(frame_h, cy + px_b)
            if ((cy + px_b) <= frame_h) bbox_y2 <= cy + px_b;
            else                        bbox_y2 <= frame_h;
        end
    end

endmodule
