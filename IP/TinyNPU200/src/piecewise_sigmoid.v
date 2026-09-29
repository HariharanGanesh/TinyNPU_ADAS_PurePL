`timescale 1ns / 1ps
module piecewise_sigmoid (
    input  wire [7:0]  x_in,
    output wire [7:0]  sigmoid_out
);
    wire [8:0] x_ext = {1'b0, x_in};
    reg  [7:0] out_r;

    always @(*) begin
        if (x_in <= 8'd64) begin
            out_r = 8'h00;
        end else if (x_in <= 8'd96) begin
            out_r = ((x_in - 8'd64) * 8'd15) >> 4;
        end else if (x_in <= 8'd128) begin
            out_r = 8'd30 + ((x_in - 8'd96) * 8'd3);
        end else if (x_in <= 8'd160) begin
            out_r = 8'd128 + ((x_in - 8'd128) * 8'd3);
        end else if (x_in <= 8'd192) begin
            out_r = 8'd225 + (((x_in - 8'd160) * 8'd15) >> 4);
        end else begin
            out_r = 8'hFF;
        end
    end
    assign sigmoid_out = out_r;
endmodule

