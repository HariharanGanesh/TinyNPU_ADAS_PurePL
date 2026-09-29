with open("IP/TinyNPU200/src/streaming_topk.v", "w") as f:
    f.write("""`timescale 1ns / 1ps
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
""")

    f.write("    wire signed [7:0] scores [0:255];\n")
    f.write("    genvar i;\n")
    f.write("    generate\n")
    f.write("        for (i=0; i<256; i=i+1) begin : init_scores\n")
    f.write("            if (i < NUM_CLASSES) begin\n")
    f.write("                assign scores[i] = class_logits_in[i*8 +: 8];\n")
    f.write("            end else begin\n")
    f.write("                assign scores[i] = 8'h80; // Minimum value\n")
    f.write("            end\n")
    f.write("        end\n")
    f.write("    endgenerate\n\n")

    for level in range(9):
        nodes = 256 >> level
        f.write(f"    wire signed [7:0] val_l{level}[0:{nodes-1}];\n")
        f.write(f"    wire [7:0] idx_l{level}[0:{nodes-1}];\n")
    
    f.write("\n")
    f.write("    generate\n")
    f.write("        for (i=0; i<256; i=i+1) begin : l0\n")
    f.write("            assign val_l0[i] = scores[i];\n")
    f.write("            assign idx_l0[i] = i;\n")
    f.write("        end\n")
    f.write("    endgenerate\n\n")

    for level in range(1, 9):
        prev_nodes = 256 >> (level - 1)
        nodes = prev_nodes // 2
        f.write(f"    generate\n")
        f.write(f"        for (i=0; i<{nodes}; i=i+1) begin : l{level}\n")
        f.write(f"            assign val_l{level}[i] = (val_l{level-1}[2*i] > val_l{level-1}[2*i+1]) ? val_l{level-1}[2*i] : val_l{level-1}[2*i+1];\n")
        f.write(f"            assign idx_l{level}[i] = (val_l{level-1}[2*i] > val_l{level-1}[2*i+1]) ? idx_l{level-1}[2*i] : idx_l{level-1}[2*i+1];\n")
        f.write(f"        end\n")
        f.write(f"    endgenerate\n\n")

    f.write("""
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
""")