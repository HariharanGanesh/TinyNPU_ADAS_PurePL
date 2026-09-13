// =============================================================================
// Module: bram_sensor_emulator.v
// Project: TinyNPU
// Description:
//   ROM-based AXI4-Stream Sensor Emulator for hardware-in-loop verification.
//   Synthesizable on PYNQ-Z2 / Spartan-7 PL fabric.
//   Replaces external Python sensor simulator with pure hardware stimulus.
//
//   Operation:
//     - Preloaded at synthesis time with test frame data (from $readmemh in sim)
//     - Streams pixels frame-by-frame at configurable throttle rate
//     - Asserts s_axis_tvalid continuously (max bandwidth) or at 1/THROTTLE rate
//     - Generates TLAST at frame boundary (every FRAME_SIZE bytes)
//     - After all frames sent: wraps around (LOOP_EN=1) or idles (LOOP_EN=0)
//     - frame_start pulse: fires at start of every new frame
//     - frame_done pulse:  fires when last byte of a frame exits TREADY handshake
//
//   Hex File Format:
//     One byte per line in hex (e.g., "A3\n"). Address 0 = first pixel of frame 0.
//     Total bytes = NUM_FRAMES × FRAME_SIZE.
//
//   Simulation: $readmemh loads from verif/tb/test_sensor_data.hex
//   Hardware:   BRAM initialized from block design IP core (same hex file)
//
//   Verilog-2001. Synthesizable.
// =============================================================================

`timescale 1ns / 1ps

module bram_sensor_emulator #(
    parameter NUM_FRAMES    = 4,                         // Number of test frames
    parameter FRAME_W       = 64,                        // Frame width (pixels)
    parameter FRAME_H       = 64,                        // Frame height (pixels)
    parameter NUM_CHANNELS  = 1,                         // Channels per pixel (1 = greyscale)
    parameter THROTTLE      = 1,                         // 1 = full rate, N = send 1 byte every N cycles
    parameter LOOP_EN       = 1,                         // 1 = loop frames indefinitely
    parameter ROM_INIT_FILE = "test_sensor_data.hex"     // Stimulus hex file
) (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Stream output to TinyNPU s_axis
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready,

    // Status outputs
    output reg         frame_start,   // 1-cycle pulse at start of each frame
    output reg         frame_done,    // 1-cycle pulse at end of each frame
    output reg  [15:0] frame_count,   // Number of frames emitted
    output reg         all_done       // Asserted when all frames sent (LOOP_EN=0 only)
);

    // =========================================================================
    // Derived Parameters
    // =========================================================================
    localparam FRAME_SIZE   = FRAME_W * FRAME_H * NUM_CHANNELS;  // Bytes per frame
    localparam ROM_DEPTH    = NUM_FRAMES * FRAME_SIZE;            // Total ROM entries

    // =========================================================================
    // ROM Declaration
    // =========================================================================
    reg [7:0] pixel_rom [0:ROM_DEPTH-1];

    initial begin
        $readmemh(ROM_INIT_FILE, pixel_rom);
        $display("[SensorEmulator] Loaded %0d bytes from %s (%0d frames of %0d×%0d pixels)",
                 ROM_DEPTH, ROM_INIT_FILE, NUM_FRAMES, FRAME_W, FRAME_H);
    end

    // =========================================================================
    // Address Counter and Throttle
    // =========================================================================
    integer rom_addr;                // Current ROM read address
    integer throttle_cnt;            // Throttle divider counter
    integer pixel_in_frame;          // Pixel position within current frame

    // =========================================================================
    // AXI-Stream Output FSM
    // =========================================================================
    localparam ST_IDLE     = 2'd0;
    localparam ST_ACTIVE   = 2'd1;
    localparam ST_DONE     = 2'd2;

    reg [1:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            rom_addr       <= 0;
            throttle_cnt   <= 0;
            pixel_in_frame <= 0;
            frame_count    <= 16'h0;
            frame_start    <= 1'b0;
            frame_done     <= 1'b0;
            all_done       <= 1'b0;
            m_axis_tdata   <= 8'h00;
            m_axis_tvalid  <= 1'b0;
            m_axis_tlast   <= 1'b0;
        end else begin
            // Default: clear pulse outputs
            frame_start <= 1'b0;
            frame_done  <= 1'b0;

            case (state)
                // ----------------------------------------------------------
                // ST_IDLE: Start streaming after reset
                // ----------------------------------------------------------
                ST_IDLE: begin
                    m_axis_tvalid  <= 1'b0;
                    m_axis_tlast   <= 1'b0;
                    rom_addr       <= 0;
                    pixel_in_frame <= 0;
                    throttle_cnt   <= 0;
                    frame_count    <= 16'h0;
                    frame_start    <= 1'b1;   // Announce first frame start
                    state          <= ST_ACTIVE;
                end

                // ----------------------------------------------------------
                // ST_ACTIVE: Streaming pixels from ROM
                // ----------------------------------------------------------
                ST_ACTIVE: begin
                    // Throttle control: only advance every THROTTLE cycles
                    if (throttle_cnt < THROTTLE - 1) begin
                        throttle_cnt  <= throttle_cnt + 1;
                        m_axis_tvalid <= 1'b0;
                    end else begin
                        throttle_cnt  <= 0;
                        m_axis_tvalid <= 1'b1;

                        // Load current pixel into tdata (present to interface)
                        m_axis_tdata <= pixel_rom[rom_addr];

                        // TLAST: assert on last pixel of frame
                        if (pixel_in_frame == FRAME_SIZE - 1)
                            m_axis_tlast <= 1'b1;
                        else
                            m_axis_tlast <= 1'b0;
                    end

                    // When handshake completes (TVALID & TREADY)
                    if (m_axis_tvalid && m_axis_tready) begin
                        // Advance to next pixel
                        if (pixel_in_frame == FRAME_SIZE - 1) begin
                            // End of frame
                            frame_done     <= 1'b1;
                            pixel_in_frame <= 0;

                            if (rom_addr == ROM_DEPTH - 1) begin
                                // End of all frames
                                frame_count <= frame_count + 16'h1;
                                if (LOOP_EN) begin
                                    // Wrap around
                                    rom_addr    <= 0;
                                    frame_start <= 1'b1;
                                end else begin
                                    // All done
                                    m_axis_tvalid <= 1'b0;
                                    m_axis_tlast  <= 1'b0;
                                    all_done      <= 1'b1;
                                    state         <= ST_DONE;
                                end
                            end else begin
                                // Advance to next frame
                                rom_addr    <= rom_addr + 1;
                                frame_count <= frame_count + 16'h1;
                                frame_start <= 1'b1;
                            end
                        end else begin
                            // Within frame: advance pixel
                            rom_addr       <= rom_addr + 1;
                            pixel_in_frame <= pixel_in_frame + 1;
                        end
                    end
                end

                // ----------------------------------------------------------
                // ST_DONE: All frames sent (LOOP_EN=0)
                // ----------------------------------------------------------
                ST_DONE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    all_done      <= 1'b1;
                    // Stay here until reset
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    // =========================================================================
    // Simulation Monitoring
    // =========================================================================
    always @(posedge clk) begin
        if (frame_done) begin
            $display("[SensorEmulator] @%0t: Frame %0d of %0d emitted. ROM addr = %0d",
                     $time, frame_count, NUM_FRAMES, rom_addr);
        end
        if (all_done) begin
            $display("[SensorEmulator] @%0t: ALL %0d frames emitted. Sensor emulator idle.",
                     $time, frame_count);
        end
    end
`endif

endmodule
