`timescale 1ns / 1ps
// =============================================================================
// Module: sparse_candidate_packer
// Project: NPU300PMADAS
// Description:
//   Packs valid detections into 128-bit sparse records and writes them to BRAM.
//   Manages the BRAM write pointer and asserts an overflow flag if the number
//   of detections exceeds MAX_CANDIDATES.
//
// 128-bit Record Format:
//   [127:112] class_id
//   [111:96]  score
//   [95:80]   bbox_y2
//   [79:64]   bbox_x2
//   [63:48]   bbox_y1
//   [47:32]   bbox_x1
//   [31:16]   scale_id
//   [15:0]    flags (reserved)
// =============================================================================

module sparse_candidate_packer #(
    parameter ADDR_WIDTH = 10 // e.g. 1024 candidates max
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Config
    input  wire [ADDR_WIDTH-1:0] max_candidates,
    input  wire                  clear_frame, // pulse to reset for new frame
    
    // Inputs from Top-K & DFL Decoder
    input  wire         valid_in,
    input  wire [15:0]  class_id,
    input  wire [15:0]  score,
    input  wire [15:0]  bbox_x1,
    input  wire [15:0]  bbox_y1,
    input  wire [15:0]  bbox_x2,
    input  wire [15:0]  bbox_y2,
    input  wire [15:0]  scale_id,
    input  wire [15:0]  flags,
    
    // BRAM Interface (Write-Only from PL perspective)
    output reg                   bram_wr_en,
    output reg  [ADDR_WIDTH-1:0] bram_wr_addr,
    output wire [127:0]          bram_wr_data,
    
    // Status to RISC-V CSR
    output reg  [ADDR_WIDTH-1:0] candidate_count,
    output reg                   overflow_flag
);

    assign bram_wr_data = {class_id, score, bbox_y2, bbox_x2, bbox_y1, bbox_x1, scale_id, flags};

    always @(posedge clk) begin
        if (!rst_n) begin
            bram_wr_en      <= 0;
            bram_wr_addr    <= 0;
            candidate_count <= 0;
            overflow_flag   <= 0;
        end else if (clear_frame) begin
            bram_wr_en      <= 0;
            bram_wr_addr    <= 0;
            candidate_count <= 0;
            overflow_flag   <= 0;
        end else begin
            if (valid_in) begin
                if (candidate_count < max_candidates) begin
                    bram_wr_en      <= 1;
                    bram_wr_addr    <= candidate_count;
                    candidate_count <= candidate_count + 1;
                end else begin
                    // Buffer is full, drop candidate and assert overflow
                    bram_wr_en    <= 0;
                    overflow_flag <= 1;
                end
            end else begin
                bram_wr_en <= 0;
            end
        end
    end

endmodule
