`timescale 1ns / 1ps
/*
 * Module: safety_unit
 * Description: ISO-26262 Hardware Watchdog Timer (WDT).
 * The RISC-V core must toggle the wdt_pet signal periodically.
 * If the WDT overflows, a system_fault is latched.
 */

module safety_unit #(
    // 125 MHz clock. 125,000,000 ticks = 1 second.
    // 12,500,000 ticks = 100 ms timeout.
    parameter TIMEOUT_CYCLES = 32'd12500000 
)(
    input  wire clk,
    input  wire rst_n,          // Hardware reset
    input  wire wdt_pet,        // Toggle from RISC-V to reset timer
    
    output reg  system_fault    // Goes high if WDT expires
);

    reg [31:0] wdt_counter;
    reg last_wdt_pet;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wdt_counter <= 32'd0;
            system_fault <= 1'b0;
            last_wdt_pet <= 1'b0;
        end else begin
            last_wdt_pet <= wdt_pet;
            
            if (system_fault == 1'b0) begin
                // Check for pet (edge detection)
                if (wdt_pet != last_wdt_pet) begin
                    wdt_counter <= 32'd0; // Reset timer
                end else begin
                    wdt_counter <= wdt_counter + 1;
                    if (wdt_counter >= TIMEOUT_CYCLES) begin
                        system_fault <= 1'b1; // Trigger fault!
                    end
                end
            end
            // Note: If system_fault is 1, it stays 1 until hard rst_n (Latching fault)
        end
    end

endmodule
