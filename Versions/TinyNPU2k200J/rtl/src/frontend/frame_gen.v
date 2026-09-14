// =============================================================================
// Module: frame_gen.v
// Project: TinyNPU — PL Front-End Frame Generator
// Description:
//   Generates synthetic test frames directly in PL and streams them to
//   TinyNPU via AXI-Stream. Bypasses PS/DMA entirely.
//
//   Generates: 160x160x1 (grayscale) or 160x160x3 (RGB) frames
//   Pattern:   Moving gradient bar simulating a ballistic projectile
//
//   AXI-Stream output: 8-bit per pixel, TLAST on last byte of frame
//
//   Timing (@ 100MHz, 160x160 = 25600 pixels):
//     Frame period:   25600 cycles = 256µs
//     Single-channel: 256µs per frame
//     With backpressure from NPU: stream pauses (tready=0)
//
//   PIPELINE NOTE:
//     in_bar comparison is registered (1-cycle pipeline stage) to break
//     the 16-level combinatorial chain that was causing WNS=-1.285ns.
//     bar_end = bar_pos + BAR_WIDTH is pre-computed to avoid chained adder.
//     This adds 1 cycle output latency but does NOT affect functional correctness.
//
// ASIC-PORTABLE: Yes — no vendor primitives
// Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module frame_gen #(
    parameter IMG_WIDTH   = 160,   // Frame width in pixels
    parameter IMG_HEIGHT  = 160,   // Frame height in pixels
    parameter CHANNELS    = 1,     // 1=grayscale, 3=RGB
    parameter BAR_WIDTH   = 16,    // Simulated projectile bar width (pixels)
    parameter BAR_SPEED   = 2      // Bar movement per frame (pixels)
) (
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        enable,          // 1 = stream frames continuously
    input  wire        single_shot,     // Pulse 1 = send exactly one frame

    // AXI-Stream output → NPU s_axis
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready,

    // Status
    output reg  [31:0] frame_count,     // Total frames sent
    output reg         frame_done       // Pulses 1 cycle at end of each frame
);

    // -------------------------------------------------------------------------
    // Pixel counter
    // -------------------------------------------------------------------------
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT * CHANNELS;

    reg [17:0] pixel_cnt;   // Up to 160*160*3 = 76800
    reg [7:0]  bar_pos;     // Current bar horizontal position (0..IMG_WIDTH-1)
    reg [7:0]  bar_end;     // Pre-computed: bar_pos + BAR_WIDTH (registered)
    reg        sending;

    // -------------------------------------------------------------------------
    // Pixel coordinates — registered counters (no division/modulo)
    // -------------------------------------------------------------------------
    reg [7:0]  px_col;
    reg [7:0]  px_row;
    reg [1:0]  px_ch;

    // -------------------------------------------------------------------------
    // PIPELINE STAGE 1: Register the bar detection comparison
    //   Break the critical path: px_col comparators + bar_pos+BAR_WIDTH adder
    //   were creating 16 logic levels. Registering in_bar cuts this to ~5 levels.
    //
    //   in_bar_d1: registered 1 cycle after px_col is valid
    //   We look-ahead: compute in_bar for (px_col+1) so output is aligned.
    // -------------------------------------------------------------------------
    // Look-ahead column (so registered in_bar aligns with the NEXT pixel output)
    wire [7:0] next_col = (px_ch == CHANNELS-1) ?
                              (px_col == IMG_WIDTH-1 ? 8'd0 : px_col + 8'd1) :
                              px_col;

    wire       in_bar_comb = (next_col >= bar_pos) && (next_col < bar_end);
    reg        in_bar_d1;   // registered: used in S_SEND to drive pixel_val

    // Background: row-based gradient (0..255) — use registered px_row
    // For next pixel row (look-ahead)
    wire [7:0] next_row = (px_ch == CHANNELS-1 && px_col == IMG_WIDTH-1) ?
                              (px_row == IMG_HEIGHT-1 ? 8'd0 : px_row + 8'd1) :
                              px_row;
    wire [1:0] next_ch  = (px_ch == CHANNELS-1) ? 2'd0 : px_ch + 2'd1;

    reg [7:0]  px_row_d1;   // registered row for output alignment
    reg [1:0]  px_ch_d1;    // registered channel for output alignment

    // Bar pixel value based on channel
    wire [7:0] bar_val = (px_ch_d1 == 0) ? 8'hFF :   // R channel
                         (px_ch_d1 == 1) ? 8'hA0 :   // G channel
                                           8'h20;     // B channel

    // Final pixel value — uses registered in_bar_d1 (short path, ~3 levels)
    wire [7:0] pixel_val = in_bar_d1 ? bar_val : px_row_d1;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam S_IDLE = 2'd0;
    localparam S_SEND = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg       do_send;  // latched trigger

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            pixel_cnt     <= 0;
            px_col        <= 0;
            px_row        <= 0;
            px_ch         <= 0;
            px_row_d1     <= 0;
            px_ch_d1      <= 0;
            bar_pos       <= 0;
            bar_end       <= BAR_WIDTH[7:0];
            frame_count   <= 0;
            frame_done    <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= 0;
            do_send       <= 0;
            sending       <= 0;
            in_bar_d1     <= 0;
        end else begin
            frame_done <= 0;  // default: de-assert

            // Always register the look-ahead bar comparison
            // This pipeline register fires every cycle, reducing critical path
            in_bar_d1 <= in_bar_comb;
            px_row_d1 <= next_row;
            px_ch_d1  <= next_ch;

            case (state)
                // ---------------------------------------------------------
                S_IDLE: begin
                    m_axis_tvalid <= 0;
                    m_axis_tlast  <= 0;
                    pixel_cnt     <= 0;
                    px_col        <= 0;
                    px_row        <= 0;
                    px_ch         <= 0;
                    sending       <= 0;

                    if (enable || single_shot) begin
                        state   <= S_SEND;
                        sending <= 1;
                    end
                end

                // ---------------------------------------------------------
                S_SEND: begin
                    m_axis_tvalid <= 1;
                    m_axis_tdata  <= pixel_val;
                    m_axis_tlast  <= (pixel_cnt == TOTAL_PIXELS - 1);

                    if (m_axis_tready && m_axis_tvalid) begin
                        if (pixel_cnt == TOTAL_PIXELS - 1) begin
                            // End of frame
                            frame_done  <= 1;
                            frame_count <= frame_count + 1;

                            // Advance bar position for next frame
                            // Update bar_end simultaneously to avoid adding adder to critical path
                            if (bar_pos + BAR_SPEED + BAR_WIDTH >= IMG_WIDTH) begin
                                bar_pos <= 0;
                                bar_end <= BAR_WIDTH[7:0];
                            end else begin
                                bar_pos <= bar_pos + BAR_SPEED[7:0];
                                bar_end <= bar_pos + BAR_SPEED[7:0] + BAR_WIDTH[7:0];
                            end

                            state <= S_DONE;
                        end else begin
                            pixel_cnt <= pixel_cnt + 1;

                            // Coordinate counters (registered, no division)
                            if (px_ch == CHANNELS - 1) begin
                                px_ch <= 0;
                                if (px_col == IMG_WIDTH - 1) begin
                                    px_col <= 0;
                                    if (px_row == IMG_HEIGHT - 1)
                                        px_row <= 0;
                                    else
                                        px_row <= px_row + 1;
                                end else begin
                                    px_col <= px_col + 1;
                                end
                            end else begin
                                px_ch <= px_ch + 1;
                            end
                        end
                    end
                end

                // ---------------------------------------------------------
                S_DONE: begin
                    m_axis_tvalid <= 0;
                    m_axis_tlast  <= 0;
                    pixel_cnt     <= 0;
                    px_col        <= 0;
                    px_row        <= 0;
                    px_ch         <= 0;

                    // If continuous mode, go again immediately
                    if (enable)
                        state <= S_SEND;
                    else
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
