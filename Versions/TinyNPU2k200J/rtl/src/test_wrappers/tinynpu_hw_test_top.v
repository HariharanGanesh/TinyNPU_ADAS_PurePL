`timescale 1ns / 1ps

module tinynpu_hw_test_top (
    input  wire        sys_clk,   // e.g. 125 MHz board clock
    input  wire        sys_rst_n, // board reset (BTN0)
    input  wire        btn_start, // BTN1 to start test
    
    output wire [3:0]  led        // LEDs for status
);

    // =========================================================================
    // Clocking & Reset (195 MHz PLL)
    // =========================================================================
    wire clk_195mhz;
    wire pll_locked;
    
    sys_pll u_pll (
        .clk_in1(sys_clk),
        .clk_out1(clk_195mhz),
        .locked(pll_locked)
    );

    wire clk = clk_195mhz;
    wire rst_n = (~sys_rst_n) & pll_locked; // NPU held in reset until PLL locks
    
    // Simple button debounce/edge detect for start
    reg [2:0] btn_sync;
    always @(posedge clk) begin
        if (!rst_n) btn_sync <= 3'b000;
        else btn_sync <= {btn_sync[1:0], btn_start};
    end
    wire start_pulse = (btn_sync[2:1] == 2'b01);
    
    // =========================================================================
    // NPU Interface Wires
    // =========================================================================
    wire [31:0] s_axis_tdata;
    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire        s_axis_tlast;
    
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire        m_axis_tlast;
    
    // We tie off AXI-Lite config to hardcoded defaults for the test
    wire [31:0] awaddr = 0; wire awvalid = 0; wire awready;
    wire [31:0] wdata = 0;  wire wvalid = 0;  wire wready;
    wire        bvalid;     wire bready = 1;
    wire [31:0] araddr = 0; wire arvalid = 0; wire arready;
    wire [31:0] rdata;      wire rvalid;      wire rready = 1;
    
    // Status
    wire emu_done;
    wire test_done;
    wire test_pass;

    // =========================================================================
    // BRAM Sensor Emulator (Input Source)
    // =========================================================================
    bram_sensor_emulator #(
        .DATA_WIDTH(32),
        .IMAGE_SIZE(1024), // Example size
        .INIT_FILE("dummy.hex")
    ) u_emulator (
        .clk(clk),
        .rst_n(rst_n),
        .start_stream(start_pulse),
        
        .m_axis_tdata(s_axis_tdata),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tready(s_axis_tready),
        .m_axis_tlast(s_axis_tlast),
        
        .done(emu_done)
    );

    // =========================================================================
    // TinyNPU Core
    // =========================================================================
    tinynpu_top #(
        .DATA_WIDTH(8),
        .ARRAY_ROWS(8),
        .ARRAY_COLS(8)
    ) u_npu (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata),   .s_axi_wvalid(wvalid),   .s_axi_wready(wready),
        .s_axi_bresp(),        .s_axi_bvalid(bvalid),   .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata),   .s_axi_rresp(),          .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // =========================================================================
    // Hardware Scoreboard (Output Checker)
    // =========================================================================
    hw_scoreboard #(
        .DATA_WIDTH(32),
        .NUM_OUTPUTS(16),
        .GOLDEN_FILE("dummy.hex")
    ) u_scoreboard (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axis_tdata(m_axis_tdata),
        .s_axis_tvalid(m_axis_tvalid),
        .s_axis_tready(m_axis_tready),
        .s_axis_tlast(m_axis_tlast),
        
        .test_done(test_done),
        .test_pass(test_pass)
    );

    // =========================================================================
    // LED Status Mapping
    // =========================================================================
    // LED 0: Power/Reset OK
    // LED 1: Emulator streaming complete
    // LED 2: Test Done (Scoreboard finished)
    // LED 3: Test Pass (Green=Pass)
    assign led[0] = rst_n;
    assign led[1] = emu_done;
    assign led[2] = test_done;
    assign led[3] = test_pass;

endmodule
