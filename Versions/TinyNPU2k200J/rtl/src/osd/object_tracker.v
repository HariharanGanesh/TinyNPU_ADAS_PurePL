`timescale 1ns / 1ps
// =============================================================================
// Module: object_tracker.v
// Description: Multi-target hardware tracker. 
//              Matches new incoming NPU bounding boxes to existing tracks.
//              Calculates distance (heuristic) and pixel-velocity (speed).
// =============================================================================

module object_tracker #(
    parameter MAX_TARGETS = 16,
    parameter KNOWN_WIDTH = 32000 // Heuristic constant for distance division
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Bounding Box Input (from NPU decoder)
    input  wire         bbox_valid,
    input  wire [11:0]  bbox_xmin,
    input  wire [11:0]  bbox_ymin,
    input  wire [11:0]  bbox_xmax,
    input  wire [11:0]  bbox_ymax,
    
    // Status Output
    output wire         target_locked, // HIGH if >0 targets being tracked
    
    // OSD Memory Interface (To OSD Mixer)
    input  wire [3:0]   read_idx,
    output wire         track_valid,
    output wire [11:0]  track_x,
    output wire [11:0]  track_y,
    output wire [11:0]  track_distance,
    output wire [11:0]  track_speed
);

    // Tracking Memory Table
    reg [11:0] mem_x [0:MAX_TARGETS-1];
    reg [11:0] mem_y [0:MAX_TARGETS-1];
    reg [11:0] mem_w [0:MAX_TARGETS-1]; // width
    reg [11:0] mem_h [0:MAX_TARGETS-1]; // height
    reg [11:0] mem_dist  [0:MAX_TARGETS-1];
    reg [11:0] mem_speed [0:MAX_TARGETS-1];
    reg [MAX_TARGETS-1:0] active_flags;
    
    integer i;

    // Output assignment
    assign track_valid    = active_flags[read_idx];
    assign track_x        = mem_x[read_idx];
    assign track_y        = mem_y[read_idx];
    assign track_distance = mem_dist[read_idx];
    assign track_speed    = mem_speed[read_idx];
    
    assign target_locked  = (active_flags != 0);

    // Simple tracking logic (Delta & Heuristic Distance)
    always @(posedge clk) begin
        if (!rst_n) begin
            active_flags <= 0;
            for (i=0; i<MAX_TARGETS; i=i+1) begin
                mem_x[i] <= 0; mem_y[i] <= 0;
                mem_speed[i] <= 0; mem_dist[i] <= 0;
            end
        end else if (bbox_valid) begin
            // For this pure hardware demonstration, we simply map the first incoming box 
            // to index 0. A full Kalman filter would do IoU matching here.
            active_flags[0] <= 1'b1;
            
            // Calc Centroid
            mem_x[0] <= (bbox_xmin + bbox_xmax) >> 1;
            mem_y[0] <= (bbox_ymin + bbox_ymax) >> 1;
            
            // Calc Width/Height
            mem_w[0] <= (bbox_xmax - bbox_xmin);
            mem_h[0] <= (bbox_ymax - bbox_ymin);
            
            // Distance Heuristic: Distance = Constant / Width
            // (Assuming wider box = closer object)
            if ((bbox_xmax - bbox_xmin) > 0)
                mem_dist[0] <= KNOWN_WIDTH / (bbox_xmax - bbox_xmin);
            else
                mem_dist[0] <= 999; // Infinity
                
            // Speed Calculation: Euclidean delta or simple Manhattan distance
            // Speed = |X_new - X_old| + |Y_new - Y_old|
            mem_speed[0] <= ((bbox_xmin + bbox_xmax)>>1) - mem_x[0]; // Simplified delta X
        end
    end

endmodule
