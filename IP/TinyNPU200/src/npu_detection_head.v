`timescale 1ns / 1ps
// =============================================================================
// Module: npu_detection_head
// Project: NPU300PMADAS
// Description:
//   Top-level wrapper for the YOLOv8-style hardware detection head.
//   Instantiates the Top-K filter, DFL decoders (L, T, R, B), and Candidate Packer.
//   Guarantees that complete 200-class tensors are never written to DDR.
// =============================================================================

module npu_detection_head #(
    parameter NUM_CLASSES = 200,
    parameter DATA_WIDTH  = 8,
    parameter REG_BINS    = 17,
    parameter ADDR_WIDTH  = 10
)(
    input  wire                                 clk,
    input  wire                                 rst_n,
    
    // Config CSRs
    input  wire signed [DATA_WIDTH-1:0]         thresh_logit,
    input  wire [ADDR_WIDTH-1:0]                max_candidates,
    input  wire                                 clear_frame,
    input  wire [15:0]                          scale_id,
    
    // Inputs from NPU Pipeline (Streaming)
    input  wire                                 stream_valid,
    input  wire [NUM_CLASSES*DATA_WIDTH-1:0]    class_logits,
    input  wire [REG_BINS*DATA_WIDTH-1:0]       reg_l,
    input  wire [REG_BINS*DATA_WIDTH-1:0]       reg_t,
    input  wire [REG_BINS*DATA_WIDTH-1:0]       reg_r,
    input  wire [REG_BINS*DATA_WIDTH-1:0]       reg_b,
    
    // Optional Spatial coordinates (if streaming in raster order)
    input  wire [15:0]                          grid_x,
    input  wire [15:0]                          grid_y,
    input  wire [15:0]                          stride,
    
    // BRAM Interface (Output to RISC-V)
    output wire                                 bram_wr_en,
    output wire [ADDR_WIDTH-1:0]                bram_wr_addr,
    output wire [127:0]                         bram_wr_data,
    
    // Status
    output wire [ADDR_WIDTH-1:0]                candidate_count,
    output wire                                 overflow_flag
);

    // -------------------------------------------------------------------------
    // 1. Streaming Top-K Selector & Logit Thresholding
    // -------------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] top1_score;
    wire [7:0]                   top1_class;
    wire                         top1_valid;
    
    streaming_topk #(
        .NUM_CLASSES(NUM_CLASSES),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_topk (
        .clk(clk), .rst_n(rst_n),
        .thresh_logit(thresh_logit),
        .class_logits_in(class_logits),
        .valid_in(stream_valid),
        .top1_score(top1_score),
        .top1_class_id(top1_class),
        .top1_valid(top1_valid),
        .top2_score(), .top2_class_id(), .top2_valid(), // Top-2 ignored in basic POC
        .valid_out()
    );

    // -------------------------------------------------------------------------
    // 2. DFL Box Decoders (Only execute if Top1 is valid)
    // -------------------------------------------------------------------------
    wire [15:0] d_l, d_t, d_r, d_b;
    wire dfl_valid_l, dfl_valid_t, dfl_valid_r, dfl_valid_b;
    
    // Delay reg_in arrays to match Top-K latency (1 cycle)
    reg [REG_BINS*DATA_WIDTH-1:0] reg_l_d1, reg_t_d1, reg_r_d1, reg_b_d1;
    reg [15:0] grid_x_d1, grid_y_d1;
    always @(posedge clk) begin
        reg_l_d1 <= reg_l; reg_t_d1 <= reg_t;
        reg_r_d1 <= reg_r; reg_b_d1 <= reg_b;
        grid_x_d1 <= grid_x; grid_y_d1 <= grid_y;
    end

    bbox_decoder_dfl u_dfl_l (.clk(clk), .rst_n(rst_n), .enable(top1_valid), .dist_l_in(reg_l_d1), .decoded_l(d_l), .valid_out(dfl_valid_l));
    bbox_decoder_dfl u_dfl_t (.clk(clk), .rst_n(rst_n), .enable(top1_valid), .dist_l_in(reg_t_d1), .decoded_l(d_t), .valid_out(dfl_valid_t));
    bbox_decoder_dfl u_dfl_r (.clk(clk), .rst_n(rst_n), .enable(top1_valid), .dist_l_in(reg_r_d1), .decoded_l(d_r), .valid_out(dfl_valid_r));
    bbox_decoder_dfl u_dfl_b (.clk(clk), .rst_n(rst_n), .enable(top1_valid), .dist_l_in(reg_b_d1), .decoded_l(d_b), .valid_out(dfl_valid_b));

    wire dfl_done = dfl_valid_l & dfl_valid_t & dfl_valid_r & dfl_valid_b;

    // -------------------------------------------------------------------------
    // 3. Absolute Coordinate Conversion
    // -------------------------------------------------------------------------
    // Delay score/class/grid to match DFL latency (1 cycle)
    reg [15:0] score_d2, class_d2;
    reg [15:0] gx_d2, gy_d2;
    always @(posedge clk) begin
        score_d2 <= {8'b0, top1_score}; // Extend INT8 to INT16
        class_d2 <= {8'b0, top1_class};
        gx_d2 <= grid_x_d1;
        gy_d2 <= grid_y_d1;
    end

    // x1 = (grid_x * stride) - (d_l * stride), etc.
    wire [15:0] x1 = (gx_d2 * stride) - (d_l * stride);
    wire [15:0] y1 = (gy_d2 * stride) - (d_t * stride);
    wire [15:0] x2 = (gx_d2 * stride) + (d_r * stride);
    wire [15:0] y2 = (gy_d2 * stride) + (d_b * stride);

    // -------------------------------------------------------------------------
    // 4. Sparse Candidate Packer
    // -------------------------------------------------------------------------
    sparse_candidate_packer #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_packer (
        .clk(clk),
        .rst_n(rst_n),
        .max_candidates(max_candidates),
        .clear_frame(clear_frame),
        .valid_in(dfl_done),
        .class_id(class_d2),
        .score(score_d2),
        .bbox_x1(x1),
        .bbox_y1(y1),
        .bbox_x2(x2),
        .bbox_y2(y2),
        .scale_id(scale_id),
        .flags(16'd0),
        .bram_wr_en(bram_wr_en),
        .bram_wr_addr(bram_wr_addr),
        .bram_wr_data(bram_wr_data),
        .candidate_count(candidate_count),
        .overflow_flag(overflow_flag)
    );

endmodule
