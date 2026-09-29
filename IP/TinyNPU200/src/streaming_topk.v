`timescale 1ns / 1ps
module streaming_topk #(
    parameter NUM_CLASSES = 200,
    parameter DATA_WIDTH  = 8
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire signed [DATA_WIDTH-1:0]       thresh_logit,
    input  wire [NUM_CLASSES*DATA_WIDTH-1:0]  class_logits_in,
    input  wire                               valid_in,
    
    output reg  signed [DATA_WIDTH-1:0]       top1_score,
    output reg  [7:0]                         top1_class_id,
    output reg                                top1_valid,
    output reg  signed [DATA_WIDTH-1:0]       top2_score,
    output reg  [7:0]                         top2_class_id,
    output reg                                top2_valid,
    output reg                                valid_out
);
    wire signed [7:0] scores [0:255];
    genvar i;
    generate
        for (i=0; i<256; i=i+1) begin : init_scores
            if (i < NUM_CLASSES) begin
                assign scores[i] = class_logits_in[i*8 +: 8];
            end else begin
                assign scores[i] = 8'h80; // Minimum value
            end
        end
    endgenerate

    wire signed [7:0] val_l0[0:255];
    wire [7:0] idx_l0[0:255];
    wire signed [7:0] val_l1[0:127];
    wire [7:0] idx_l1[0:127];
    wire signed [7:0] val_l2[0:63];
    wire [7:0] idx_l2[0:63];
    wire signed [7:0] val_l3[0:31];
    wire [7:0] idx_l3[0:31];
    wire signed [7:0] val_l4[0:15];
    wire [7:0] idx_l4[0:15];
    wire signed [7:0] val_l5[0:7];
    wire [7:0] idx_l5[0:7];
    wire signed [7:0] val_l6[0:3];
    wire [7:0] idx_l6[0:3];
    wire signed [7:0] val_l7[0:1];
    wire [7:0] idx_l7[0:1];
    wire signed [7:0] val_l8[0:0];
    wire [7:0] idx_l8[0:0];

    generate
        for (i=0; i<256; i=i+1) begin : l0
            assign val_l0[i] = scores[i];
            assign idx_l0[i] = i;
        end
    endgenerate

    generate
        for (i=0; i<128; i=i+1) begin : l1
            assign val_l1[i] = (val_l0[2*i] > val_l0[2*i+1]) ? val_l0[2*i] : val_l0[2*i+1];
            assign idx_l1[i] = (val_l0[2*i] > val_l0[2*i+1]) ? idx_l0[2*i] : idx_l0[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<64; i=i+1) begin : l2
            assign val_l2[i] = (val_l1[2*i] > val_l1[2*i+1]) ? val_l1[2*i] : val_l1[2*i+1];
            assign idx_l2[i] = (val_l1[2*i] > val_l1[2*i+1]) ? idx_l1[2*i] : idx_l1[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<32; i=i+1) begin : l3
            assign val_l3[i] = (val_l2[2*i] > val_l2[2*i+1]) ? val_l2[2*i] : val_l2[2*i+1];
            assign idx_l3[i] = (val_l2[2*i] > val_l2[2*i+1]) ? idx_l2[2*i] : idx_l2[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<16; i=i+1) begin : l4
            assign val_l4[i] = (val_l3[2*i] > val_l3[2*i+1]) ? val_l3[2*i] : val_l3[2*i+1];
            assign idx_l4[i] = (val_l3[2*i] > val_l3[2*i+1]) ? idx_l3[2*i] : idx_l3[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<8; i=i+1) begin : l5
            assign val_l5[i] = (val_l4[2*i] > val_l4[2*i+1]) ? val_l4[2*i] : val_l4[2*i+1];
            assign idx_l5[i] = (val_l4[2*i] > val_l4[2*i+1]) ? idx_l4[2*i] : idx_l4[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<4; i=i+1) begin : l6
            assign val_l6[i] = (val_l5[2*i] > val_l5[2*i+1]) ? val_l5[2*i] : val_l5[2*i+1];
            assign idx_l6[i] = (val_l5[2*i] > val_l5[2*i+1]) ? idx_l5[2*i] : idx_l5[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<2; i=i+1) begin : l7
            assign val_l7[i] = (val_l6[2*i] > val_l6[2*i+1]) ? val_l6[2*i] : val_l6[2*i+1];
            assign idx_l7[i] = (val_l6[2*i] > val_l6[2*i+1]) ? idx_l6[2*i] : idx_l6[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<1; i=i+1) begin : l8
            assign val_l8[i] = (val_l7[2*i] > val_l7[2*i+1]) ? val_l7[2*i] : val_l7[2*i+1];
            assign idx_l8[i] = (val_l7[2*i] > val_l7[2*i+1]) ? idx_l7[2*i] : idx_l7[2*i+1];
        end
    endgenerate


    always @(posedge clk) begin
        if (!rst_n) begin
            top1_valid    <= 0;
            top1_score    <= 8'h80;
            top1_class_id <= 0;
            top2_score    <= 8'h80;
            top2_class_id <= 0;
            top2_valid    <= 0;
            valid_out     <= 0;
        end else begin
            top1_valid    <= valid_in;
            valid_out     <= valid_in;
            if (valid_in) begin
                top1_score    <= val_l8[0];
                top1_class_id <= idx_l8[0];
                top2_score    <= 8'h80;
                top2_class_id <= 0;
                top2_valid    <= 0;
            end
        end
    end
endmodule
