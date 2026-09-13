// =============================================================================
// Module: result_capture.v
// Project: TinyNPU — PL-side Detection Result Parser
// Description:
//   Captures the NPU AXI-Stream output and extracts structured detection data.
//   NPU output format (per detection):
//     Bytes  0-3:  bbox_x  (Q12.4 fixed point)
//     Bytes  4-7:  bbox_y  (Q12.4 fixed point)
//     Bytes  8-11: bbox_w  (Q12.4 fixed point)
//     Bytes 12-15: bbox_h  (Q12.4 fixed point)
//     Byte   16:   confidence (UINT8, 0=0.0, 255=1.0)
//     TLAST: asserted on byte 16
//
//   All outputs registered and valid-flagged for latency-safe readout.
//   ASIC-portable. Verilog-2001.
// =============================================================================

`timescale 1ns / 1ps

module result_capture (
    input  wire        clk,
    input  wire        rst_n,

    // AXI-Stream input (from NPU m_axis)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,

    // Parsed detection output
    output reg  [31:0] det_bbox_x,
    output reg  [31:0] det_bbox_y,
    output reg  [31:0] det_bbox_w,
    output reg  [31:0] det_bbox_h,
    output reg  [7:0]  det_confidence,
    output reg         det_valid       // 1-cycle pulse on new detection
);

    // Always ready to receive NPU output
    assign s_axis_tready = 1'b1;

    // Word counter (each word = 32 bits = 4 bytes)
    // Word 0: bbox_x, Word 1: bbox_y, Word 2: bbox_w,
    // Word 3: bbox_h, Word 4[7:0]: confidence
    reg [2:0] word_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_cnt       <= 0;
            det_bbox_x     <= 0;
            det_bbox_y     <= 0;
            det_bbox_w     <= 0;
            det_bbox_h     <= 0;
            det_confidence <= 0;
            det_valid      <= 0;
        end else begin
            det_valid <= 0;  // default: de-assert

            if (s_axis_tvalid) begin
                case (word_cnt)
                    3'd0: det_bbox_x     <= s_axis_tdata;
                    3'd1: det_bbox_y     <= s_axis_tdata;
                    3'd2: det_bbox_w     <= s_axis_tdata;
                    3'd3: det_bbox_h     <= s_axis_tdata;
                    3'd4: begin
                        det_confidence <= s_axis_tdata[7:0];
                        // det_valid is now controlled strictly by tlast
                    end
                    default: ;
                endcase

                if (s_axis_tlast) begin
                    word_cnt <= 0;
                    if (word_cnt == 3'd4) det_valid <= 1'b1;
                end else begin
                    word_cnt <= word_cnt + 1;
                end
            end
        end
    end

endmodule
