`timescale 1ns / 1ps
/*
 * Module: riscv_adas_subsystem
 * Description: Fully integrated RISC-V ADAS subsystem. Contains the PicoRV32 core,
 * internal instruction/data BRAM, and the ISO-26262 ADAS Zonal Controller logic.
 * Exposes a slave AXI4-Lite port so the Zynq ARM can load firmware into the BRAM 
 * and configure the system.
 */

module riscv_adas_subsystem (
    input wire clk,
    input wire rst_n,
    
    // External ADAS Inputs/Outputs
    input  wire sw_brake_arm,
    output wire out_warning_ped,
    output wire out_warning_lane,
    output wire out_warning_sign,
    output wire out_brake_authorized,
    output wire out_system_fault,
    
    // AXI4-Lite Master Interface (To NPU)
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_awaddr,
    output wire [ 2:0] m_axi_awprot,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire [31:0] m_axi_wdata,
    output wire [ 3:0] m_axi_wstrb,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [31:0] m_axi_araddr,
    output wire [ 2:0] m_axi_arprot,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire [31:0] m_axi_rdata
);

    // --- PicoRV32 Native Memory Interface ---
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    
    // Instantiate PicoRV32
    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(0),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA(0),
        .TWO_STAGE_SHIFT(0),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .CATCH_MISALIGN(0),
        .CATCH_ILLINSN(0)
    ) picorv32_core (
        .clk      (clk      ),
        .resetn   (rst_n    ),
        .trap     (         ),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr (mem_addr ),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    // --- Address Decoding ---
    // 0x0000_0000 to 0x0000_0FFF : 4KB BRAM (Firmware)
    // 0x4200_0000 to 0x4200_000F : ADAS Control Registers (Internal)
    // 0x4000_0000, 0x4800_0000, 0x4A..., 0x4C... : External AXI
    
    wire sel_bram = (mem_addr[31:28] == 4'h0);
    wire sel_adas = (mem_addr[31:28] == 4'h4) && (mem_addr[27:24] == 4'h2);
    wire sel_axi  = (mem_addr[31:28] == 4'h4) && (mem_addr[27:24] != 4'h2);

    // --- 4KB BRAM ---
    reg [31:0] firmware_bram [0:1023];
    reg [31:0] bram_rdata;
    reg bram_ready;
    
    initial begin
        $readmemh("firmware.hex", firmware_bram);
    end
    
    always @(posedge clk) begin
        bram_ready <= 0;
        if (mem_valid && sel_bram) begin
            bram_ready <= 1;
            if (mem_wstrb[0]) firmware_bram[mem_addr[11:2]] [7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) firmware_bram[mem_addr[11:2]] [15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) firmware_bram[mem_addr[11:2]] [23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) firmware_bram[mem_addr[11:2]] [31:24] <= mem_wdata[31:24];
            bram_rdata <= firmware_bram[mem_addr[11:2]];
        end
    end

    // --- ADAS Controller Interface Adapter ---
    // Adapt PicoRV32 native memory to ADAS AXI4-Lite style registers
    reg adas_ready;
    reg [31:0] adas_rdata;
    
    // Internal ADAS Registers
    reg [31:0] reg_detections;
    reg [31:0] reg_configs;
    reg        reg_wdt_pet;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_detections <= 0;
            reg_configs <= 0;
            reg_wdt_pet <= 0;
            adas_ready <= 0;
            adas_rdata <= 0;
        end else begin
            adas_ready <= 0;
            if (mem_valid && sel_adas) begin
                adas_ready <= 1;
                // Write
                if (|mem_wstrb) begin
                    case (mem_addr[7:0])
                        8'h00: reg_detections <= mem_wdata;
                        8'h04: reg_configs <= mem_wdata;
                        8'h08: reg_wdt_pet <= ~reg_wdt_pet;
                    endcase
                end
                // Read
                case (mem_addr[7:0])
                    8'h00: adas_rdata <= reg_detections;
                    8'h04: adas_rdata <= reg_configs;
                    8'h0C: adas_rdata <= {31'd0, out_system_fault};
                    default: adas_rdata <= 32'd0;
                endcase
            end
        end
    end

    // --- AXI Adapter ---
    wire axi_ready;
    wire [31:0] axi_rdata;
    
    picorv32_axi_adapter u_axi_adapter (
        .clk(clk), .resetn(rst_n),
        .mem_axi_awvalid(m_axi_awvalid), .mem_axi_awready(m_axi_awready), .mem_axi_awaddr(m_axi_awaddr), .mem_axi_awprot(m_axi_awprot),
        .mem_axi_wvalid (m_axi_wvalid ), .mem_axi_wready (m_axi_wready ), .mem_axi_wdata (m_axi_wdata ), .mem_axi_wstrb (m_axi_wstrb ),
        .mem_axi_bvalid (m_axi_bvalid ), .mem_axi_bready (m_axi_bready ),
        .mem_axi_arvalid(m_axi_arvalid), .mem_axi_arready(m_axi_arready), .mem_axi_araddr(m_axi_araddr), .mem_axi_arprot(m_axi_arprot),
        .mem_axi_rvalid (m_axi_rvalid ), .mem_axi_rready (m_axi_rready ), .mem_axi_rdata (m_axi_rdata ),
        
        .mem_valid(mem_valid & sel_axi),
        .mem_instr(mem_instr),
        .mem_ready(axi_ready),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(axi_rdata)
    );

    // Mux read data and ready signal back to PicoRV32
    assign mem_ready = (sel_bram & bram_ready) | (sel_adas & adas_ready) | (sel_axi & axi_ready);
    assign mem_rdata = sel_bram ? bram_rdata : 
                       sel_adas ? adas_rdata : 
                       sel_axi  ? axi_rdata  : 32'hDEADBEEF;

    // --- ADAS Instantiations ---
    wire emergency_trigger;
    
    sensor_fusion u_fusion (
        .clk(clk),
        .rst_n(rst_n),
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
        .clk(clk),
        .rst_n(rst_n),
        .wdt_pet(reg_wdt_pet),
        .system_fault(out_system_fault)
    );
    
    security_unit u_security (
        .clk(clk),
        .rst_n(rst_n),
        .sw_brake_arm(sw_brake_arm),
        .emergency_trigger(emergency_trigger),
        .system_fault(out_system_fault),
        .brake_authorized(out_brake_authorized)
    );

endmodule
