// =============================================================================
// Module: activation_buffer.v
// Project: TinyNPU
// Description:
//   Dual-port BRAM-based Activation Buffer with double-buffering (ping-pong).
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module activation_buffer #(
    parameter DATA_WIDTH   = 8,
    parameter BUFFER_DEPTH = 1024,   // Words per bank
    parameter ADDR_WIDTH   = 10      // log2(BUFFER_DEPTH)
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Write Port (DMA -> Buffer)
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    input  wire                     wr_en,

    // Read Port (Buffer -> Systolic Array)
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output reg  [DATA_WIDTH-1:0]    rd_data,
    input  wire                     rd_en,

    // Ping-Pong Control
    input  wire                     swap_buffers,
    output reg                      ping_pong_sel,
    output reg                      buffer_ready
);

    // Xilinx BRAM inference attribute
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] bank_a [0:BUFFER_DEPTH-1];

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] bank_b [0:BUFFER_DEPTH-1];

    // Ping-Pong Selection Register
    always @(posedge clk) begin
        if (!rst_n) begin
            ping_pong_sel <= 1'b0;
            buffer_ready  <= 1'b0;
        end else if (swap_buffers) begin
            ping_pong_sel <= ~ping_pong_sel;
            buffer_ready  <= 1'b1;
        end
    end

    // Write Logic
    always @(posedge clk) begin
        if (wr_en) begin
            $display("[BUF_WRITE] Time=%0t bank=%b wr_addr=%d wr_data=%h", $time, ping_pong_sel, wr_addr, wr_data);
            if (ping_pong_sel == 1'b0) begin
                bank_b[wr_addr] <= wr_data;
            end else begin
                bank_a[wr_addr] <= wr_data;
            end
        end
    end

    // Read Logic
    always @(posedge clk) begin
        if (rd_en) begin
            if (ping_pong_sel == 1'b0) begin
                rd_data <= bank_a[rd_addr];
            end else begin
                rd_data <= bank_b[rd_addr];
            end
        end
    end

endmodule
