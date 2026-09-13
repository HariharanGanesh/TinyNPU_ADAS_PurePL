`timescale 1ns / 1ps
/*
 * Module: security_unit
 * Description: Physical interlock FSM. Prevents the AI from applying the brakes
 * unless a physical switch (sw_brake_arm) is armed AND the system is fault-free.
 */

module security_unit (
    input  wire clk,
    input  wire rst_n,
    
    input  wire sw_brake_arm,       // Physical switch to allow braking
    input  wire emergency_trigger,  // From sensor_fusion
    input  wire system_fault,       // From safety_unit
    
    output reg  brake_authorized    // Final output to the physical brake actuator (or LED5)
);

    // FSM States
    localparam STATE_LOCKED     = 2'd0;
    localparam STATE_VERIFY     = 2'd1;
    localparam STATE_UNLOCKED   = 2'd2;
    localparam STATE_FAULT      = 2'd3;

    reg [1:0] current_state, next_state;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_LOCKED;
        end else begin
            if (system_fault)
                current_state <= STATE_FAULT;
            else
                current_state <= next_state;
        end
    end

    // FSM Next State & Output Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        brake_authorized = 1'b0;

        case (current_state)
            STATE_LOCKED: begin
                if (sw_brake_arm)
                    next_state = STATE_VERIFY;
            end
            
            STATE_VERIFY: begin
                if (!sw_brake_arm)
                    next_state = STATE_LOCKED;
                else if (emergency_trigger)
                    next_state = STATE_UNLOCKED;
            end
            
            STATE_UNLOCKED: begin
                brake_authorized = 1'b1; // BRAKES APPLIED
                if (!sw_brake_arm)
                    next_state = STATE_LOCKED; // Physical disarm overrides everything
                else if (!emergency_trigger)
                    next_state = STATE_VERIFY;
            end
            
            STATE_FAULT: begin
                // In a fault state, we disable brakes (safe-state)
                brake_authorized = 1'b0; 
                // Only a hard reset can exit STATE_FAULT (due to safety_unit latching)
            end
            
            default: next_state = STATE_LOCKED;
        endcase
    end

endmodule
