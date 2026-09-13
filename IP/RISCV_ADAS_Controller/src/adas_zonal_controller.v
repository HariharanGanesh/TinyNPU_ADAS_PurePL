`timescale 1ns / 1ps
/*
 * Module: adas_zonal_controller
 * Description: Top-level ADAS logic block containing Sensor Fusion, Safety Watchdog,
 * and Security Interlock. Exposes an AXI4-Lite interface so a master (RISC-V or ARM)
 * can write detection flags and pet the watchdog.
 */

module adas_zonal_controller (
    // AXI4-Lite Clock and Reset
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    
    // AXI4-Lite Write Address Channel
    input  wire [31:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    // AXI4-Lite Write Data Channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    // AXI4-Lite Write Response Channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    // AXI4-Lite Read Address Channel
    input  wire [31:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    // AXI4-Lite Read Data Channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    
    // Physical Board Inputs
    input  wire        sw_brake_arm,
    
    // Physical Board Outputs (LEDs)
    output wire        out_warning_ped,
    output wire        out_warning_lane,
    output wire        out_warning_sign,
    output wire        out_brake_authorized,
    output wire        out_system_fault
);

    // --- AXI4-Lite Registers ---
    // Offset 0x00: Detections (Bit 0: Ped, Bit 1: Obs, Bit 2: Lane, Bit 3: Sign)
    // Offset 0x04: Configs (Bit 0: PedEn, Bit 1: ObsEn, Bit 2: LaneEn, Bits 4:3: LaneSev)
    // Offset 0x08: Watchdog Pet (Write any value to toggle)
    
    reg [31:0] reg_detections;
    reg [31:0] reg_configs;
    reg        reg_wdt_pet;
    
    // AXI Write Logic (Simplified for brevity, assuming well-behaved master)
    reg aw_en;
    assign s_axi_awready = ~s_axi_awvalid & ~s_axi_wvalid & aw_en;
    assign s_axi_wready  = ~s_axi_awvalid & ~s_axi_wvalid & aw_en;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_bvalid  = s_axi_awvalid & s_axi_wvalid;
    
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            aw_en <= 1'b1;
            reg_detections <= 0;
            reg_configs <= 0;
            reg_wdt_pet <= 0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && aw_en) begin
                aw_en <= 1'b0;
                case (s_axi_awaddr[7:0])
                    8'h00: reg_detections <= s_axi_wdata;
                    8'h04: reg_configs <= s_axi_wdata;
                    8'h08: reg_wdt_pet <= ~reg_wdt_pet; // Toggle on write
                endcase
            end else if (s_axi_bready && s_axi_bvalid) begin
                aw_en <= 1'b1;
            end
        end
    end

    // AXI Read Logic
    assign s_axi_arready = 1'b1;
    assign s_axi_rvalid  = s_axi_arvalid;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rdata   = (s_axi_araddr[7:0] == 8'h00) ? reg_detections :
                           (s_axi_araddr[7:0] == 8'h04) ? reg_configs :
                           (s_axi_araddr[7:0] == 8'h0C) ? {31'd0, out_system_fault} : 32'd0;

    // --- Sub-module Instantiations ---
    wire emergency_trigger;
    
    sensor_fusion u_fusion (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .ped_detected(reg_detections[0]),
        .obs_detected(reg_detections[1]),
        .lane_detected(reg_detections[2]),
        .sign_overspeed(reg_detections[3]),
        .lane_severity(reg_configs[4:3]),
        .ped_en(reg_configs[0]),
        .obs_en(reg_configs[1]),
        .lane_en(reg_configs[2]),
        .emergency_trigger(emergency_trigger),
        .warning_ped(out_warning_ped),
        .warning_lane(out_warning_lane),
        .warning_sign(out_warning_sign)
    );
    
    safety_unit u_safety (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .wdt_pet(reg_wdt_pet),
        .system_fault(out_system_fault)
    );
    
    security_unit u_security (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .sw_brake_arm(sw_brake_arm),
        .emergency_trigger(emergency_trigger),
        .system_fault(out_system_fault),
        .brake_authorized(out_brake_authorized)
    );

endmodule
