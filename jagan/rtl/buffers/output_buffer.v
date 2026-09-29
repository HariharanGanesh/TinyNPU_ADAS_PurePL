// =============================================================================
// Module: output_buffer.v
// Project: TinyNPU
// Description:
//   FIFO-based Output Buffer to cache processed INT8 activations from the
//   activation unit before they are drained via AXI4-Stream.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module output_buffer #(
    parameter DATA_WIDTH = 8,
    parameter NUM_CHANNELS = 8,
    parameter FIFO_DEPTH = 512,
    parameter ADDR_WIDTH = 9
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // Write Interface (from Activation Unit)
    input  wire [DATA_WIDTH*NUM_CHANNELS-1:0] wr_data,
    input  wire                               wr_en,
    output wire                               full,

    // Read Interface (to AXI4-Stream Master)
    output wire [DATA_WIDTH*NUM_CHANNELS-1:0] rd_data,
    input  wire                               rd_en,
    output wire                               empty,

    // Status
    output reg  [ADDR_WIDTH:0]                count
);

    localparam WIDTH = DATA_WIDTH * NUM_CHANNELS;

    (* ram_style = "block" *)
    reg [WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    // Write Logic
    always @(posedge clk) begin
        if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
        end
    end

    // Read Logic (Synchronous for BRAM Inference)
    reg [WIDTH-1:0] rd_data_reg;
    always @(posedge clk) begin
        rd_data_reg <= mem[rd_ptr];
    end
    assign rd_data = rd_data_reg;

    // Pointer and Count Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin
                    wr_ptr <= wr_ptr + 1'b1;
                    count  <= count + 1'b1;
                end
                2'b01: begin
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin
                    wr_ptr <= wr_ptr + 1'b1;
                    rd_ptr <= rd_ptr + 1'b1;
                end
                default: ;
            endcase
        end
    end

endmodule
