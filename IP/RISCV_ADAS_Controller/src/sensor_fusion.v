`timescale 1ns / 1ps
/*
 * Module: sensor_fusion
 * Description: ADAS Sensor Fusion module inspired by ISO-26262 principles.
 * It combines inputs from the NPU (via RISC-V) and assigns severity scores.
 * Uses a sticky latch for emergency states to prevent glitches from clearing faults.
 */

module sensor_fusion (
    input  wire clk,
    input  wire rst_n,          // Active-low reset (from BTN3)
    
    // NPU / RISC-V Inputs
    input  wire ped_detected,
    input  wire obs_detected,
    input  wire lane_detected,
    input  wire sign_overspeed,
    
    // Switch / Severity Config Inputs
    input  wire [1:0] lane_severity, // 00=safe, 11=critical
    input  wire ped_en,
    input  wire obs_en,
    input  wire lane_en,
    
    // Outputs
    output reg  emergency_trigger,
    output reg  warning_ped,
    output reg  warning_lane,
    output reg  warning_sign
);

    // Hazard Score Calculation
    wire [2:0] hazard_score;
    assign hazard_score = (ped_detected & ped_en) + 
                          (obs_detected & obs_en) + 
                          ((lane_detected & lane_en) ? {1'b0, lane_severity} : 3'd0) +
                          (sign_overspeed ? 3'd1 : 3'd0);

    // Synchronous Logic with Sticky Emergency State
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            emergency_trigger <= 1'b0;
            warning_ped <= 1'b0;
            warning_lane <= 1'b0;
            warning_sign <= 1'b0;
        end else begin
            // Warnings are continuous and reflect current state
            warning_ped  <= ped_detected & ped_en;
            warning_lane <= lane_detected & lane_en;
            warning_sign <= sign_overspeed;
            
            // EMERGENCY TRIGGER is a Sticky Latch.
            // Once the hazard score exceeds 3, the emergency state locks HIGH.
            // It can ONLY be cleared by a hard physical reset (rst_n).
            if (hazard_score >= 3'd3) begin
                emergency_trigger <= 1'b1;
            end
            // Note: No 'else' condition here for emergency_trigger to make it sticky!
        end
    end

endmodule
