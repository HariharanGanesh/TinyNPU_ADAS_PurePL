// =============================================================================
// Module: cdc_async_fifo.v
// Project: TinyNPU200
// Description: 4-entry asynchronous FIFO (Gray-code pointers) for CDC.
// =============================================================================

`timescale 1ns / 1ps

module cdc_async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH_LOG2 = 2
) (
    // Write domain
    input  wire                  clk_w,
    input  wire                  rst_w_n,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire                  wen,
    output wire                  wfull,
    // Read domain
    input  wire                  clk_r,
    input  wire                  rst_r_n,
    output reg  [DATA_WIDTH-1:0] rdata,
    input  wire                  ren,
    output wire                  rempty
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<DEPTH_LOG2)-1];

    reg [DEPTH_LOG2:0] wptr;
    reg [DEPTH_LOG2:0] wptr_gray;
    reg [DEPTH_LOG2:0] rptr;
    reg [DEPTH_LOG2:0] rptr_gray;

    (* ASYNC_REG = "TRUE" *) reg [DEPTH_LOG2:0] wptr_gray_sync1;
    (* ASYNC_REG = "TRUE" *) reg [DEPTH_LOG2:0] wptr_gray_sync2;
    (* ASYNC_REG = "TRUE" *) reg [DEPTH_LOG2:0] rptr_gray_sync1;
    (* ASYNC_REG = "TRUE" *) reg [DEPTH_LOG2:0] rptr_gray_sync2;

    function [DEPTH_LOG2:0] bin2gray;
        input [DEPTH_LOG2:0] bin;
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction

    // Write domain logic
    always @(posedge clk_w or negedge rst_w_n) begin
        if (!rst_w_n) begin
            wptr <= 0;
            wptr_gray <= 0;
        end else if (wen && !wfull) begin
            mem[wptr[DEPTH_LOG2-1:0]] <= wdata;
            wptr <= wptr + 1;
            wptr_gray <= bin2gray(wptr + 1);
        end
    end

    // Sync read pointer to write domain
    always @(posedge clk_w or negedge rst_w_n) begin
        if (!rst_w_n) begin
            rptr_gray_sync1 <= 0;
            rptr_gray_sync2 <= 0;
        end else begin
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end
    end

    assign wfull = (wptr_gray == {~rptr_gray_sync2[DEPTH_LOG2:DEPTH_LOG2-1], rptr_gray_sync2[DEPTH_LOG2-2:0]});

    // Read domain logic
    always @(posedge clk_r or negedge rst_r_n) begin
        if (!rst_r_n) begin
            rptr <= 0;
            rptr_gray <= 0;
            rdata <= 0;
        end else if (ren && !rempty) begin
            rdata <= mem[rptr[DEPTH_LOG2-1:0]];
            rptr <= rptr + 1;
            rptr_gray <= bin2gray(rptr + 1);
        end
    end

    // Sync write pointer to read domain
    always @(posedge clk_r or negedge rst_r_n) begin
        if (!rst_r_n) begin
            wptr_gray_sync1 <= 0;
            wptr_gray_sync2 <= 0;
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end

    assign rempty = (rptr_gray == wptr_gray_sync2);

endmodule
