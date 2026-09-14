// =============================================================================
// Module: hardswish_lut.v
// Project: TinyNPU
// Description:
//   256-entry ROM implementing INT8 HardSwish.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module hardswish_lut (
    input  wire [7:0] din,
    output reg  [7:0] dout
);

    always @(*) begin
        if ($signed(din) <= -3) begin
            dout = 8'sh00;
        end else if ($signed(din) >= 3) begin
            dout = din;
        end else begin
            case (din)
                8'hfe: dout = 8'sh00; // -2: (-2*1)/6 = 0
                8'hff: dout = 8'sh00; // -1: (-1*2)/6 = 0
                8'h00: dout = 8'sh00; // 0
                8'h01: dout = 8'sh01; // 1: (1*4)/6 = 0 -> round to 1
                8'h02: dout = 8'sh02; // 2: (2*5)/6 = 1 -> round to 2
                default: dout = din;
            endcase
        end
    end

endmodule
