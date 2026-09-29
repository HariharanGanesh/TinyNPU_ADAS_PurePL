// =============================================================================
// Module: sigmoid_lut.v
// Project: TinyNPU
// Description:
//   256-entry BRAM-based sigmoid activation LUT for YOLOv8n INT8 detection head.
//
//   INPUT:  8-bit signed INT8 value x (range -128..127)
//           Represents floating-point range [-8.0, +7.9375] with scale=1/16
//
//   OUTPUT: 8-bit unsigned INT8 sigmoid(x)*255
//           Represents [0.0, 1.0) in UINT8 format
//           Format: 0x00=0.000, 0x80=0.502, 0xFF=1.000
//
//   LATENCY: 2 clock cycles (1 cycle address register + 1 cycle BRAM read)
//
//   SYNTHESIS: Inferred as BRAM 18K in Xilinx, ROM in ASIC
//   ASIC-PORTABLE: Yes — initial block used for ROM preload, ASIC PDK supports
//
//   YOLOv8n Usage:
//     Detection head confidence: conf_score = sigmoid_lut(raw_conf_output)
//     Class scores:              cls_score   = sigmoid_lut(raw_cls_output)
//
//   Scale Factor Note:
//     The scale factor (1/16) is fixed for this LUT.
//     For different quantization scales, regenerate sigmoid_lut_init.hex
//     using: out[i] = round(sigmoid((i-128) / Q_SCALE) * 255)
//     where Q_SCALE is the inverse quantization scale of your detection head.
//
//   Verilog-2001. ASIC-ready.
// =============================================================================

`timescale 1ns / 1ps

module sigmoid_lut #(
    parameter INIT_FILE = "sigmoid_lut_init.hex"  // Precomputed LUT hex file
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,          // Input valid strobe
    input  wire [7:0]  x_in,              // INT8 input (unsigned index 0..255)
    output reg  [7:0]  sigmoid_out,       // UINT8 sigmoid output
    output reg         valid_out          // Output valid (2-cycle latency)
);

    // =========================================================================
    // ROM: 256 x 8-bit sigmoid LUT
    // Precomputed: lut_mem[i] = round(sigmoid((i-128)/16.0) * 255)
    // Input range: [-8.0, +7.9375] float -> [0, 255] UINT8 index
    // Synthesis: Vivado maps to 1x BRAM 18K (or distributed LUT-RAM for small)
    // =========================================================================
    reg [7:0] lut_mem [0:255];

    initial begin
        $readmemh(INIT_FILE, lut_mem);
    end

    // =========================================================================
    // Stage 1: Register address input (1 cycle) — BRAM address pipe
    // =========================================================================
    reg [7:0] addr_d1;
    reg       valid_d1;

    always @(posedge clk) begin
        if (!rst_n) begin
            addr_d1  <= 8'h00;
            valid_d1 <= 1'b0;
        end else begin
            addr_d1  <= x_in;     // unsigned index directly
            valid_d1 <= valid_in;
        end
    end

    // =========================================================================
    // Stage 2: Registered BRAM read output (1 cycle) — BRAM output pipe
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            sigmoid_out <= 8'h00;
            valid_out   <= 1'b0;
        end else begin
            sigmoid_out <= lut_mem[addr_d1];
            valid_out   <= valid_d1;
        end
    end

endmodule
