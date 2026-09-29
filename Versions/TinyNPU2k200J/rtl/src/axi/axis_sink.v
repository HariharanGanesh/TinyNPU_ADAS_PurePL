// =============================================================================
// Module: axis_sink.v
// Project: TinyNPU
// Description:
//   AXI4-Stream Slave (Sink) — receives a continuous pixel stream and writes
//   it into the activation ping-pong buffer.
//
//   ADDITION: Spatial Crop Window Preprocessor
//   ------------------------------------------
//   Pixels are tracked using a 2D (x, y) coordinate counter synchronized
//   with the stream. Only pixels that fall within the configured
//   [crop_x, crop_x + crop_w) x [crop_y, crop_y + crop_h) window are written
//   to the activation buffer. All other pixels are silently discarded.
//   This eliminates the need to store full high-resolution frames and directly
//   saves activation buffer memory and reduces inference latency.
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module axis_sink #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter TILE_SIZE       = 64,
    parameter ADDR_WIDTH      = 10
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // AXI4-Stream Slave Interface
    input  wire [AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                    s_axis_tvalid,
    output reg                     s_axis_tready,
    input  wire                    s_axis_tlast,   // End of row marker

    // Buffer Write Interface
    output reg  [ADDR_WIDTH-1:0]   buf_wr_addr,
    output reg  [AXIS_DATA_WIDTH-1:0]  buf_wr_data,
    output reg                     buf_wr_en,

    // Control Interface
    input  wire                    buf_swap_ack,
    input  wire                    buf_full,

    // Spatial crop configuration (from CSR)
    input  wire [15:0]             crop_x,
    input  wire [15:0]             crop_y,
    input  wire [15:0]             crop_w,
    input  wire [15:0]             crop_h,
    // When crop_en=0, all pixels are accepted (bypass mode)
    input  wire                    crop_en,

    // Status outputs
    output reg                     tile_received,
    output reg                     frame_done,
    output reg  [ADDR_WIDTH:0]     bytes_received
);

    // States
    localparam ST_IDLE    = 2'd0;
    localparam ST_RECEIVE = 2'd1;
    localparam ST_FULL    = 2'd2;

    reg [1:0]   state;
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // =========================================================================
    // Spatial Coordinate Tracking
    // =========================================================================
    reg [15:0] pix_x;  // Current pixel X coordinate in stream
    reg [15:0] pix_y;  // Current pixel Y coordinate in stream

    // A pixel is inside the crop window when crop is enabled
    wire in_crop_window = (!crop_en) ||
                          ((pix_x >= crop_x) && (pix_x < (crop_x + crop_w)) &&
                           (pix_y >= crop_y) && (pix_y < (crop_y + crop_h)));

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            wr_ptr         <= 0;
            buf_wr_addr    <= 0;
            buf_wr_data    <= 0;
            buf_wr_en      <= 1'b0;
            s_axis_tready  <= 1'b0;
            tile_received  <= 1'b0;
            frame_done     <= 1'b0;
            bytes_received <= 0;
            pix_x          <= 0;
            pix_y          <= 0;
        end else begin
            buf_wr_en     <= 1'b0;
            tile_received <= 1'b0;
            frame_done    <= 1'b0;

            case (state)
                ST_IDLE: begin
                    wr_ptr         <= 0;
                    bytes_received <= 0;
                    pix_x          <= 0;
                    pix_y          <= 0;
                    s_axis_tready  <= 1'b1;

                    if (s_axis_tvalid && s_axis_tready) begin
                        // Advance coordinate
                        if (s_axis_tlast) begin
                            pix_x      <= 0;
                            pix_y      <= pix_y + 1'b1;
                            frame_done <= 1'b1;
                        end else begin
                            pix_x <= pix_x + 1'b1;
                        end

                        if (in_crop_window) begin
                            buf_wr_addr    <= 0;
                            buf_wr_data    <= s_axis_tdata;
                            buf_wr_en      <= 1'b1;
                            wr_ptr         <= 1'b1;
                            bytes_received <= (AXIS_DATA_WIDTH/8);
                        end

                        if (TILE_SIZE == 1 && in_crop_window) begin
                            tile_received <= 1'b1;
                            s_axis_tready <= 1'b0;
                            state         <= ST_FULL;
                        end else begin
                            state <= ST_RECEIVE;
                        end
                    end
                end

                ST_RECEIVE: begin
                    s_axis_tready <= ~buf_full;

                    if (s_axis_tvalid && s_axis_tready) begin
                        // Advance spatial coordinate counter
                        if (s_axis_tlast) begin
                            pix_x      <= 0;
                            pix_y      <= pix_y + 1'b1;
                            frame_done <= 1'b1;
                        end else begin
                            pix_x <= pix_x + 1'b1;
                        end

                        // Only write to buffer if this pixel is inside crop window
                        if (in_crop_window) begin
                            buf_wr_addr    <= wr_ptr;
                            buf_wr_data    <= s_axis_tdata;
                            buf_wr_en      <= 1'b1;
                            wr_ptr         <= wr_ptr + 1'b1;
                            bytes_received <= bytes_received + (AXIS_DATA_WIDTH/8);

                            // Tile boundary check on CROPPED byte count
                            if (bytes_received >= TILE_SIZE - (AXIS_DATA_WIDTH/8)) begin
                                tile_received <= 1'b1;
                                s_axis_tready <= 1'b0;
                                state         <= ST_FULL;
                            end
                        end
                    end
                end

                ST_FULL: begin
                    s_axis_tready <= 1'b0;
                    if (buf_swap_ack) begin
                        wr_ptr         <= 0;
                        bytes_received <= 0;
                        state          <= ST_RECEIVE;
                        s_axis_tready  <= 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

