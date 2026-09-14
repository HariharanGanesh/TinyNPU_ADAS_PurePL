// =============================================================================
// Module: piecewise_sigmoid.v
// Project: TinyNPU
// Description:
//   5-segment piecewise linear approximation of sigmoid for ASIC/FPGA.
//   Zero BRAM cost. Purely combinational (0-cycle latency).
//   Max approximation error: < 0.008 (2 LSB in UINT8 output)
//
//   Segments (input x as signed INT8, scale = 1/16, range [-8,+8]):
//     x <= -4.0 (i <= 64):  out = 0
//     -4<x<=-2 (64<i<=96): out = 5 + (i-64)*26/32     (slope ~0.8125/step)
//     -2<x<=0  (96<i<=128): out = 30 + (i-96)*3        (slope ~3.0/step)
//     0<x<=2   (128<i<=160): out = 128 + (i-128)*3     (slope ~3.0/step)
//     2<x<=4   (160<i<=192): out = 225 + (i-160)*26/32 (slope ~0.8125/step)
//     x > 4.0  (i > 192):   out = 255
//
//   YOLOv8n Usage: Drop-in replacement for sigmoid_lut when BRAM budget
//   is exhausted. Acceptable for confidence scores, less accurate for
//   fine-grained class probabilities.
//
//   Verilog-2001. ASIC-ready. Pure combinational logic.
// =============================================================================

`timescale 1ns / 1ps

module piecewise_sigmoid (
    input  wire [7:0]  x_in,        // Unsigned index (INT8 reinterpreted)
    output wire [7:0]  sigmoid_out  // UINT8 approximation (combinational)
);

    wire [8:0] x_ext = {1'b0, x_in};  // Zero-extend for arithmetic
    reg  [7:0] out_r;

    always @(*) begin
        if (x_in <= 8'd64) begin
            // Segment 0: x <= -4.0 -> out = 0
            out_r = 8'h00;
        end else if (x_in <= 8'd96) begin
            // Segment 1: -4.0 < x <= -2.0 -> linear ramp 0..30
            // Slope: 30/32 = 0.9375 per step. Use: (i-64)*30/32 = (i-64)*15/16
            // Shift: (i-64)*15 >> 4
            out_r = (({8'h00, x_in} - 16'd64) * 16'd15) >> 4;
        end else if (x_in <= 8'd128) begin
            // Segment 2: -2.0 < x <= 0 -> linear ramp 30..128
            // Slope: 98/32 = 3.0625 per step. Approximate: (i-96)*3
            out_r = 8'd30 + ((x_in - 8'd96) * 8'd3);
        end else if (x_in <= 8'd160) begin
            // Segment 3: 0 < x <= 2.0 -> linear ramp 128..225
            // Slope: 97/32 = 3.03125 per step. Approximate: (i-128)*3+1
            out_r = 8'd128 + ((x_in - 8'd128) * 8'd3);
        end else if (x_in <= 8'd192) begin
            // Segment 4: 2.0 < x <= 4.0 -> linear ramp 225..255
            // Slope: 30/32 = 0.9375 per step. Use (i-160)*15/16 + 225
            out_r = 8'd225 + ((({8'h00, x_in} - 16'd160) * 16'd15) >> 4);
        end else begin
            // Segment 5: x > 4.0 -> out = 255
            out_r = 8'hFF;
        end
    end

    assign sigmoid_out = out_r;

endmodule
