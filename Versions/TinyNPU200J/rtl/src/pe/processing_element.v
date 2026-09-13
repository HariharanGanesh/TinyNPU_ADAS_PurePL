`timescale 1ns / 1ps

// Project: TinyNPU200
// Module: processing_element
// Description:
//   Processing element for a weight-stationary systolic array.
//   Modified to a 3-stage pipeline for 195 MHz timing closure on Zynq-7020 speed grade -1.
//   - Stage 1: 16-bit signed product (mul_s1)
//   - Stage 2: 32-bit sign-extend (mul_s2)
//   - Stage 3: 32-bit accumulate (psum_out)
//   Latency impact: Increases PE latency to 3 cycles. The systolic array drain counter 
//   must be adjusted to account for this extended pipeline latency.

module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
)(
    input wire clk,
    input wire reset_n,
    input wire pe_en,
    input wire psum_clear,
    input wire weight_load,
    
    input wire signed [DATA_WIDTH-1:0] weight_in,
    input wire signed [DATA_WIDTH-1:0] act_in,
    input wire act_valid_in,
    input wire signed [ACCUM_WIDTH-1:0] psum_in,
    
    output reg signed [DATA_WIDTH-1:0] act_out,
    output reg act_valid_out,
    output reg signed [ACCUM_WIDTH-1:0] psum_out
);

    localparam PE_LATENCY = 3;

    // Internal registers
    reg signed [DATA_WIDTH-1:0] weight_reg;
    reg signed [15:0] mul_s1;
    reg signed [31:0] mul_s2;
    
    reg act_valid_d1;
    reg act_valid_d2;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            weight_reg <= {DATA_WIDTH{1'b0}};
            mul_s1 <= 16'd0;
            mul_s2 <= 32'd0;
            psum_out <= {ACCUM_WIDTH{1'b0}};
            
            act_valid_d1 <= 1'b0;
            act_valid_d2 <= 1'b0;
            
            act_out <= {DATA_WIDTH{1'b0}};
            act_valid_out <= 1'b0;
        end else if (pe_en) begin
            // Weight register loading
            if (weight_load) begin
                weight_reg <= weight_in;
            end
            
            // Activation passthrough (1-cycle register)
            act_out <= act_in;
            act_valid_out <= act_valid_in;
            
            // Stage 1: 16-bit signed product
            mul_s1 <= weight_reg * act_in;
            act_valid_d1 <= act_valid_in;
            
            // Stage 2: 32-bit sign-extension
            mul_s2 <= {{16{mul_s1[15]}}, mul_s1};
            act_valid_d2 <= act_valid_d1;
            
            // Stage 3: 32-bit accumulation
            if (psum_clear) begin
                psum_out <= {ACCUM_WIDTH{1'b0}};
            end else begin
                psum_out <= psum_in + mul_s2;
            end
        end
    end

endmodule
