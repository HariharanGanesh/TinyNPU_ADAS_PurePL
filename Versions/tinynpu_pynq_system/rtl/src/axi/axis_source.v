// =============================================================================
// Module: axis_source.v
// Project: TinyNPU
// Description:
//   AXI4-Stream Master (Source) — drains processed INT8 results from the
//   output FIFO buffer and transmits them byte-serially downstream.
//
//   The output_buffer stores NUM_CHANNELS bytes per FIFO word (all output
//   channels in parallel). This module serializes each wide word into
//   NUM_CHANNELS individual DATA_WIDTH-byte AXI4-Stream beats.
//   TLAST is asserted on the final byte of the final word of each tile.
//
//   FIFO Interface Timing:
//     - buf_rd_data is COMBINATORIAL on the internal FIFO read pointer.
//     - Asserting buf_rd_en for one cycle advances the read pointer on the
//       NEXT posedge.
//     - To correctly read the next word, we must:
//         1. Assert buf_rd_en (rd_ptr advances at next posedge) → ST_POP
//         2. Wait one cycle for rd_ptr to settle              → ST_LATCH
//         3. Latch buf_rd_data into latch_word               → ST_SEND
//
//   FIRST word is captured combinatorially from buf_rd_data in ST_IDLE
//   without popping (rd_ptr unchanged). When done streaming each word,
//   buf_rd_en is pulsed to pop it.
//
// Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module axis_source #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter DATA_WIDTH      = 8,
    parameter NUM_CHANNELS    = 8,
    parameter TILE_SIZE       = 64,
    parameter ADDR_WIDTH      = 10
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // AXI4-Stream Master Interface
    output reg  [AXIS_DATA_WIDTH-1:0]         m_axis_tdata,
    output reg                                m_axis_tvalid,
    input  wire                               m_axis_tready,
    output reg                                m_axis_tlast,

    // Output Buffer Read Interface (FIFO-style, no address)
    output reg  [ADDR_WIDTH-1:0]              buf_rd_addr,  // Unused; kept for port compat
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] buf_rd_data,  // Wide parallel word from FIFO
    output reg                                buf_rd_en,    // FIFO pop strobe (1-cycle pulse)

    // Control
    input  wire                               start_drain,  // Pulse: start transmitting tile
    input  wire                               buf_empty,
    output reg                                drain_done    // Pulse: tile fully transmitted
);

    // =========================================================================
    // Derived constants
    // =========================================================================
    localparam WORD_BITS      = NUM_CHANNELS * DATA_WIDTH;  // Width of one FIFO word
    localparam WORDS_PER_TILE = TILE_SIZE / NUM_CHANNELS;   // FIFO words per tile

    // =========================================================================
    // FSM State Encoding
    // =========================================================================
    localparam ST_IDLE  = 3'd0;
    localparam ST_SEND  = 3'd1;   // Serializing bytes of latch_word
    localparam ST_POP   = 3'd2;   // buf_rd_en just pulsed; waiting for rd_ptr to advance
    localparam ST_LATCH = 3'd3;   // rd_ptr settled; capture buf_rd_data into latch_word

    // =========================================================================
    // Registers
    // =========================================================================
    reg [2:0]            state;
    reg [WORD_BITS-1:0]  latch_word;   // Captured FIFO word being serialized
    reg [3:0]            byte_idx;     // Index of byte currently on the AXI-Stream bus
    reg [3:0]            word_cnt;     // FIFO word index (0 .. WORDS_PER_TILE-1)

    // =========================================================================
    // Combinatorial helpers
    // =========================================================================
    // Next byte index (wraps at NUM_CHANNELS-1, but we gate on last_byte check)
    wire [3:0] next_byte_idx = byte_idx + 4'd1;

    // =========================================================================
    // FSM
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            buf_rd_en     <= 1'b0;
            buf_rd_addr   <= {ADDR_WIDTH{1'b0}};
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            drain_done    <= 1'b0;
            latch_word    <= {WORD_BITS{1'b0}};
            byte_idx      <= 4'd0;
            word_cnt      <= 4'd0;
        end else begin
            // Default: de-assert single-cycle strobes
            buf_rd_en  <= 1'b0;
            drain_done <= 1'b0;

            case (state)

                // =============================================================
                // ST_IDLE: Wait for start_drain.
                // Capture the first FIFO word COMBINATORIALLY from buf_rd_data
                // without advancing the read pointer. The pointer will be
                // advanced later when we finish streaming this first word.
                // =============================================================
                ST_IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    byte_idx      <= 4'd0;
                    word_cnt      <= 4'd0;
                    if (start_drain && !buf_empty) begin
                        latch_word <= buf_rd_data;   // Capture FIFO head (no pop yet)
                        state      <= ST_SEND;
                    end
                end

                // =============================================================
                // ST_SEND: Serialize bytes of latch_word onto AXI4-Stream.
                //
                // byte_idx = index of the byte CURRENTLY ON THE BUS.
                //   - When tvalid=0 (first entry): present byte 0.
                //   - When tvalid=1 & tready=1: transfer accepted; advance.
                //
                // Timing note:
                //   At posedge T, the consumer captures tdata/tvalid/tlast
                //   that were REGISTERED at posedge T-1. Our always block at T
                //   then advances the byte_idx and queues the NEXT byte.
                // =============================================================
                ST_SEND: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        // ---------------------------------------------------------
                        // Transfer accepted for current byte (byte_idx, word_cnt)
                        // ---------------------------------------------------------
                        if (m_axis_tlast) begin
                            // Last beat of the tile consumed — tile is done
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                            drain_done    <= 1'b1;
                            buf_rd_en     <= 1'b1;  // Pop the last FIFO word
                            state         <= ST_IDLE;

                        end else if (byte_idx == (NUM_CHANNELS * DATA_WIDTH / AXIS_DATA_WIDTH) - 1) begin
                            // Last byte of current word; load the next FIFO word
                            byte_idx      <= 4'd0;
                            word_cnt      <= word_cnt + 4'd1;
                            buf_rd_en     <= 1'b1;  // Pop current FIFO word
                            m_axis_tvalid <= 1'b0;  // Hold off until next word ready
                            state         <= ST_POP;

                        end else begin
                            // Advance to the next byte within this word.
                            // We use next_byte_idx (= byte_idx + 1, combinatorial)
                            // to pre-compute the next data value.
                            byte_idx     <= next_byte_idx;
                            m_axis_tdata <= latch_word[next_byte_idx * AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= (next_byte_idx == (NUM_CHANNELS * DATA_WIDTH / AXIS_DATA_WIDTH) - 1) &&
                                             (word_cnt      == WORDS_PER_TILE - 1);
                        end

                    end else if (!m_axis_tvalid) begin
                        // ---------------------------------------------------------
                        // No transfer pending yet: present byte 0 of latch_word.
                        // This branch fires on the first cycle after entering
                        // ST_SEND (from ST_IDLE or ST_LATCH), when tvalid=0.
                        // ---------------------------------------------------------
                        m_axis_tdata  <= latch_word[byte_idx * AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (byte_idx == (NUM_CHANNELS * DATA_WIDTH / AXIS_DATA_WIDTH) - 1) &&
                                         (word_cnt  == WORDS_PER_TILE - 1);
                    end
                    // else: tvalid=1 and tready=0 → backpressure; hold tdata/tvalid/tlast
                end

                // =============================================================
                // ST_POP: buf_rd_en was pulsed in the previous cycle.
                // At THIS posedge the FIFO's always block sees rd_en=1 and
                // schedules rd_ptr++ as a non-blocking assignment.
                // We must wait one more cycle before rd_ptr has settled and
                // buf_rd_data reflects the new word.
                // =============================================================
                ST_POP: begin
                    m_axis_tvalid <= 1'b0;
                    state         <= ST_LATCH;
                end

                // =============================================================
                // ST_LATCH: rd_ptr has advanced (settled from the NB update
                // in ST_POP). buf_rd_data now shows the next FIFO word.
                // Latch it and proceed to ST_SEND.
                // =============================================================
                ST_LATCH: begin
                    latch_word    <= buf_rd_data;   // Capture next word
                    m_axis_tvalid <= 1'b0;
                    state         <= ST_SEND;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
