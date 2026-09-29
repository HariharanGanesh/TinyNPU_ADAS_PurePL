`timescale 1ns / 1ps
// =============================================================================
// Module: hardware_osd_mixer.v
// Description: Mixes live HDMI pixel stream with Bounding Boxes and Text OSD.
// =============================================================================

module hardware_osd_mixer (
    input  wire         clk,
    input  wire         rst_n,
    
    // Video In (From HDMI RX)
    input  wire [23:0]  vid_in_data,
    input  wire         vid_in_hsync,
    input  wire         vid_in_vsync,
    input  wire         vid_in_de,
    
    // Video Out (To HDMI TX)
    output reg  [23:0]  vid_out_data,
    output reg          vid_out_hsync,
    output reg          vid_out_vsync,
    output reg          vid_out_de,
    
    // Tracker Interface
    output reg  [3:0]   track_idx,
    input  wire         track_valid,
    input  wire [11:0]  track_x,
    input  wire [11:0]  track_y,
    input  wire [11:0]  track_distance,
    input  wire [11:0]  track_speed,
    
    // Font ROM interface
    output reg  [7:0]   char_ascii,
    output reg  [2:0]   font_row,
    output reg  [2:0]   font_col,
    input  wire         font_pixel
);

    // Raster coordinate counters
    reg [11:0] x_pos;
    reg [11:0] y_pos;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            x_pos <= 0;
            y_pos <= 0;
        end else begin
            if (vid_in_hsync) x_pos <= 0;
            else if (vid_in_de) x_pos <= x_pos + 1;
            
            if (vid_in_vsync) y_pos <= 0;
            else if (vid_in_hsync) y_pos <= y_pos + 1;
        end
    end

    // Pipeline Stage 1: Pre-calculate bounds to break timing critical path
    // This removes 4 logic levels (adders) from the critical comparator path.
    reg [11:0] tx_minus_25, tx_plus_25;
    reg [11:0] ty_minus_25, ty_plus_25;
    reg [11:0] ty_minus_35, ty_minus_27;
    reg [11:0] tx_minus_17;

    always @(posedge clk) begin
        if (track_valid) begin
            tx_minus_25 <= track_x - 12'd25;
            tx_plus_25  <= track_x + 12'd25;
            ty_minus_25 <= track_y - 12'd25;
            ty_plus_25  <= track_y + 12'd25;
            
            ty_minus_35 <= track_y - 12'd35;
            ty_minus_27 <= track_y - 12'd27;
            tx_minus_17 <= track_x - 12'd17;
        end
    end

    // OSD Mixing Pipeline
    always @(posedge clk) begin
        // Pass through sync signals
        vid_out_hsync <= vid_in_hsync;
        vid_out_vsync <= vid_in_vsync;
        vid_out_de    <= vid_in_de;
        
        // Default to pass-through video
        vid_out_data  <= vid_in_data;
        
        // Scan target 0 (Simplified single-target check for latency)
        if (track_valid) begin
            // Draw Bounding Box (e.g. 50x50 box around centroid)
            if ((x_pos == tx_minus_25 || x_pos == tx_plus_25) && (y_pos >= ty_minus_25 && y_pos <= ty_plus_25) ||
                (y_pos == ty_minus_25 || y_pos == ty_plus_25) && (x_pos >= tx_minus_25 && x_pos <= tx_plus_25)) begin
                vid_out_data <= 24'h00FF00; // Bright Green Border
            end
            
            // Draw Text (Distance)
            // Hardcoded offset above the bounding box
            if (x_pos >= tx_minus_25 && x_pos < tx_minus_17 && y_pos >= ty_minus_35 && y_pos < ty_minus_27) begin
                char_ascii <= 8'h44; // 'D'
                font_row   <= (y_pos - ty_minus_35);
                font_col   <= (x_pos - tx_minus_25);
                if (font_pixel) vid_out_data <= 24'hFFFFFF; // White text
            end
        end
    end

endmodule
