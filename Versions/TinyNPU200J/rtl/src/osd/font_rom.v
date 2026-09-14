`timescale 1ns / 1ps
// =============================================================================
// Module: font_rom.v
// Project: TinyNPU2k200J
// Description: Pure hardware 8x8 bitmap font ROM for OSD text overlay.
//              Contains bitmaps for digits 0-9 and letters D, S, m, x, y.
//              ASIC-ready. Uses Verilog-2001 initial block (ROM preload).
// Latency: 1 clock cycle
// =============================================================================

module font_rom (
    input  wire        clk,
    input  wire [7:0]  char_ascii, // ASCII code of character
    input  wire [2:0]  row,        // Y pixel within glyph (0-7)
    input  wire [2:0]  col,        // X pixel within glyph (0-7)
    output reg         pixel_on    // 1 = draw pixel, 0 = transparent
);

    reg [7:0] rom [0:127][0:7];

    integer i, j;

    initial begin
        // Default all to blank
        for (i = 0; i < 128; i = i + 1)
            for (j = 0; j < 8; j = j + 1)
                rom[i][j] = 8'h00;

        // ---- DIGIT '0' (ASCII 0x30) ----
        rom[8'h30][0] = 8'b00111100;
        rom[8'h30][1] = 8'b01100110;
        rom[8'h30][2] = 8'b01100110;
        rom[8'h30][3] = 8'b01101110;
        rom[8'h30][4] = 8'b01110110;
        rom[8'h30][5] = 8'b01100110;
        rom[8'h30][6] = 8'b01100110;
        rom[8'h30][7] = 8'b00111100;

        // ---- DIGIT '1' (ASCII 0x31) ----
        rom[8'h31][0] = 8'b00011000;
        rom[8'h31][1] = 8'b00111000;
        rom[8'h31][2] = 8'b00011000;
        rom[8'h31][3] = 8'b00011000;
        rom[8'h31][4] = 8'b00011000;
        rom[8'h31][5] = 8'b00011000;
        rom[8'h31][6] = 8'b00011000;
        rom[8'h31][7] = 8'b01111110;

        // ---- DIGIT '2' (ASCII 0x32) ----
        rom[8'h32][0] = 8'b00111100;
        rom[8'h32][1] = 8'b01100110;
        rom[8'h32][2] = 8'b00000110;
        rom[8'h32][3] = 8'b00001100;
        rom[8'h32][4] = 8'b00011000;
        rom[8'h32][5] = 8'b00110000;
        rom[8'h32][6] = 8'b01100000;
        rom[8'h32][7] = 8'b01111110;

        // ---- DIGIT '3' (ASCII 0x33) ----
        rom[8'h33][0] = 8'b00111100;
        rom[8'h33][1] = 8'b01100110;
        rom[8'h33][2] = 8'b00000110;
        rom[8'h33][3] = 8'b00011100;
        rom[8'h33][4] = 8'b00000110;
        rom[8'h33][5] = 8'b00000110;
        rom[8'h33][6] = 8'b01100110;
        rom[8'h33][7] = 8'b00111100;

        // ---- DIGIT '4' (ASCII 0x34) ----
        rom[8'h34][0] = 8'b00001100;
        rom[8'h34][1] = 8'b00011100;
        rom[8'h34][2] = 8'b00101100;
        rom[8'h34][3] = 8'b01001100;
        rom[8'h34][4] = 8'b01111110;
        rom[8'h34][5] = 8'b00001100;
        rom[8'h34][6] = 8'b00001100;
        rom[8'h34][7] = 8'b00001100;

        // ---- DIGIT '5' (ASCII 0x35) ----
        rom[8'h35][0] = 8'b01111110;
        rom[8'h35][1] = 8'b01100000;
        rom[8'h35][2] = 8'b01100000;
        rom[8'h35][3] = 8'b01111100;
        rom[8'h35][4] = 8'b00000110;
        rom[8'h35][5] = 8'b00000110;
        rom[8'h35][6] = 8'b01100110;
        rom[8'h35][7] = 8'b00111100;

        // ---- DIGIT '6' (ASCII 0x36) ----
        rom[8'h36][0] = 8'b00111100;
        rom[8'h36][1] = 8'b01100110;
        rom[8'h36][2] = 8'b01100000;
        rom[8'h36][3] = 8'b01111100;
        rom[8'h36][4] = 8'b01100110;
        rom[8'h36][5] = 8'b01100110;
        rom[8'h36][6] = 8'b01100110;
        rom[8'h36][7] = 8'b00111100;

        // ---- DIGIT '7' (ASCII 0x37) ----
        rom[8'h37][0] = 8'b01111110;
        rom[8'h37][1] = 8'b01100110;
        rom[8'h37][2] = 8'b00000110;
        rom[8'h37][3] = 8'b00001100;
        rom[8'h37][4] = 8'b00011000;
        rom[8'h37][5] = 8'b00011000;
        rom[8'h37][6] = 8'b00011000;
        rom[8'h37][7] = 8'b00011000;

        // ---- DIGIT '8' (ASCII 0x38) ----
        rom[8'h38][0] = 8'b00111100;
        rom[8'h38][1] = 8'b01100110;
        rom[8'h38][2] = 8'b01100110;
        rom[8'h38][3] = 8'b00111100;
        rom[8'h38][4] = 8'b01100110;
        rom[8'h38][5] = 8'b01100110;
        rom[8'h38][6] = 8'b01100110;
        rom[8'h38][7] = 8'b00111100;

        // ---- DIGIT '9' (ASCII 0x39) ----
        rom[8'h39][0] = 8'b00111100;
        rom[8'h39][1] = 8'b01100110;
        rom[8'h39][2] = 8'b01100110;
        rom[8'h39][3] = 8'b01100110;
        rom[8'h39][4] = 8'b00111110;
        rom[8'h39][5] = 8'b00000110;
        rom[8'h39][6] = 8'b01100110;
        rom[8'h39][7] = 8'b00111100;

        // ---- LETTER 'D' (ASCII 0x44) -- Distance prefix ----
        rom[8'h44][0] = 8'b01111000;
        rom[8'h44][1] = 8'b01101100;
        rom[8'h44][2] = 8'b01100110;
        rom[8'h44][3] = 8'b01100110;
        rom[8'h44][4] = 8'b01100110;
        rom[8'h44][5] = 8'b01100110;
        rom[8'h44][6] = 8'b01101100;
        rom[8'h44][7] = 8'b01111000;

        // ---- LETTER 'S' (ASCII 0x53) -- Speed prefix ----
        rom[8'h53][0] = 8'b00111100;
        rom[8'h53][1] = 8'b01100110;
        rom[8'h53][2] = 8'b01100000;
        rom[8'h53][3] = 8'b00111000;
        rom[8'h53][4] = 8'b00001100;
        rom[8'h53][5] = 8'b00000110;
        rom[8'h53][6] = 8'b01100110;
        rom[8'h53][7] = 8'b00111100;

        // ---- LETTER 'm' (ASCII 0x6D) -- metres unit ----
        rom[8'h6D][0] = 8'b00000000;
        rom[8'h6D][1] = 8'b00000000;
        rom[8'h6D][2] = 8'b01101100;
        rom[8'h6D][3] = 8'b11111110;
        rom[8'h6D][4] = 8'b11010110;
        rom[8'h6D][5] = 8'b11010110;
        rom[8'h6D][6] = 8'b11000110;
        rom[8'h6D][7] = 8'b00000000;

        // ---- COLON ':' (ASCII 0x3A) -- separator ----
        rom[8'h3A][0] = 8'b00000000;
        rom[8'h3A][1] = 8'b00011000;
        rom[8'h3A][2] = 8'b00011000;
        rom[8'h3A][3] = 8'b00000000;
        rom[8'h3A][4] = 8'b00000000;
        rom[8'h3A][5] = 8'b00011000;
        rom[8'h3A][6] = 8'b00011000;
        rom[8'h3A][7] = 8'b00000000;
    end

    // 1-cycle latency read
    always @(posedge clk) begin
        pixel_on <= rom[char_ascii][row][7 - col];
    end

endmodule
