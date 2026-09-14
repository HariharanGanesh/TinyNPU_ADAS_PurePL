`timescale 1ns / 1ps

module pipelined_mult_8x8 (
    input  wire               clk,
    input  wire signed  [7:0] a,
    input  wire signed  [7:0] b,
    output reg  signed [15:0] p
);
    // Sign-extend input 'a' to 16 bits
    wire signed [15:0] a_ext = a;
    
    // Partial product generation (Radix-2, shift-and-add)
    wire signed [15:0] pp0 = b[0] ? a_ext : 16'sb0;
    wire signed [15:0] pp1 = b[1] ? (a_ext <<< 1) : 16'sb0;
    wire signed [15:0] pp2 = b[2] ? (a_ext <<< 2) : 16'sb0;
    wire signed [15:0] pp3 = b[3] ? (a_ext <<< 3) : 16'sb0;
    wire signed [15:0] pp4 = b[4] ? (a_ext <<< 4) : 16'sb0;
    wire signed [15:0] pp5 = b[5] ? (a_ext <<< 5) : 16'sb0;
    wire signed [15:0] pp6 = b[6] ? (a_ext <<< 6) : 16'sb0;
    
    // MSB (b[7]) is the sign bit in 2's complement, so we subtract
    wire signed [15:0] pp7 = b[7] ? -(a_ext <<< 7) : 16'sb0;
    
    // Stage 1 pipeline registers
    reg signed [15:0] sum_low;
    reg signed [15:0] sum_high;
    
    always @(posedge clk) begin
        // The synthesis tool will implement these as two independent 4-input adders (LUT6 structures)
        sum_low  <= pp0 + pp1 + pp2 + pp3;
        sum_high <= pp4 + pp5 + pp6 + pp7;
        
        // Stage 2 pipeline register
        p        <= sum_low + sum_high;
    end
endmodule
