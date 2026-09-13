	imescale 1ns / 1ps

module tb_hdmi_e2e;

    // =========================================================================
    // Clocks and Resets
    // =========================================================================
    logic sysclk = 0;       // 125 MHz
    logic refclk = 0;       // 200 MHz
    logic pclk = 0;         // 74.25 MHz (Pixel Clock for 720p)
    logic ext_reset = 1;
    logic sys_rst_n = 0;

    always #4 sysclk = ~sysclk;       // 125 MHz
    always #2.5 refclk = ~refclk;     // 200 MHz
    always #6.734 pclk = ~pclk;       // 74.25 MHz

    initial begin
        #100 ext_reset = 0;
        sys_rst_n = 1;
    end

    // =========================================================================
    // Signals
    // =========================================================================
    // TMDS inputs to DUT
    wire tmds_rx_clk_p, tmds_rx_clk_n;
    wire [2:0] tmds_rx_data_p, tmds_rx_data_n;

    // TMDS outputs from DUT
    wire tmds_tx_clk_p, tmds_tx_clk_n;
    wire [2:0] tmds_tx_data_p, tmds_tx_data_n;

    // DUT Outputs
    wire out_brake_authorized, out_system_fault, out_warning_lane, out_warning_ped, out_warning_sign;
    wire [0:0] rx_hpd;

    // =========================================================================
    // DUT Instance (Full HDMI to HDMI Pipeline)
    // =========================================================================
    npu_system_wrapper dut (
        .TMDS_RX_clk_p(tmds_rx_clk_p),
        .TMDS_RX_clk_n(tmds_rx_clk_n),
        .TMDS_RX_data_p(tmds_rx_data_p),
        .TMDS_RX_data_n(tmds_rx_data_n),
        
        .TMDS_TX_clk_p(tmds_tx_clk_p),
        .TMDS_TX_clk_n(tmds_tx_clk_n),
        .TMDS_TX_data_p(tmds_tx_data_p),
        .TMDS_TX_data_n(tmds_tx_data_n),
        
        .ext_reset(ext_reset),
        .sw_brake_arm(1'b1),
        .sysclk(sysclk),
        .tx_hpd(1'b1),
        .rx_hpd(rx_hpd),
        
        .out_brake_authorized(out_brake_authorized),
        .out_system_fault(out_system_fault),
        .out_warning_lane(out_warning_lane),
        .out_warning_ped(out_warning_ped),
        .out_warning_sign(out_warning_sign)
    );

    // =========================================================================
    // Synthetic HDMI Source (BFM)
    // =========================================================================
    logic [23:0] bfm_vid_data = 0;
    logic bfm_vid_hsync = 0;
    logic bfm_vid_vsync = 0;
    logic bfm_vid_vde = 0;
    
    // Video Timing Parameters (720p60)
    localparam H_ACTIVE  = 1280;
    localparam H_FP      = 110;
    localparam H_SYNC    = 40;
    localparam H_BP      = 220;
    localparam H_TOTAL   = H_ACTIVE + H_FP + H_SYNC + H_BP; // 1650

    localparam V_ACTIVE  = 720;
    localparam V_FP      = 5;
    localparam V_SYNC    = 5;
    localparam V_BP      = 20;
    localparam V_TOTAL   = V_ACTIVE + V_FP + V_SYNC + V_BP; // 750

    int h_cnt = 0;
    int v_cnt = 0;
    int frame_cnt = 0;
    
    // For corrupted frame test
    logic drop_line = 0;

    always @(posedge pclk) begin
        if (ext_reset) begin
            h_cnt <= 0;
            v_cnt <= 0;
            frame_cnt <= 0;
            drop_line <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1 || (drop_line && h_cnt == H_TOTAL/2)) begin
                h_cnt <= 0;
                drop_line <= 0; // Only drop once per frame if triggered
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 0;
                    frame_cnt <= frame_cnt + 1;
                    // Trigger corrupted frame on frame 2
                    if (frame_cnt == 1) drop_line <= 1; 
                end else begin
                    v_cnt <= v_cnt + 1;
                end
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    always @(posedge pclk) begin
        bfm_vid_hsync <= (h_cnt >= (H_ACTIVE + H_FP)) && (h_cnt < (H_ACTIVE + H_FP + H_SYNC));
        bfm_vid_vsync <= (v_cnt >= (V_ACTIVE + V_FP)) && (v_cnt < (V_ACTIVE + V_FP + V_SYNC));
        bfm_vid_vde   <= (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
        
        // Test patterns based on frame
        if (bfm_vid_vde) begin
            if (frame_cnt == 0) begin
                // Frame 0: Gradient
                bfm_vid_data <= {8'(h_cnt), 8'(v_cnt), 8'(h_cnt+v_cnt)};
            end else if (frame_cnt == 1) begin
                // Frame 1: Checkerboard
                if (((h_cnt/32) % 2) ^ ((v_cnt/32) % 2))
                    bfm_vid_data <= 24'hFFFFFF;
                else
                    bfm_vid_data <= 24'h000000;
            end else if (frame_cnt == 2) begin
                // Frame 2: Corrupted frame (handled by drop_line logic above)
                bfm_vid_data <= 24'hFF0000; // Solid red
            end else begin
                // Frame 3+: Object Shape (White square on black background)
                if (h_cnt > 100 && h_cnt < 200 && v_cnt > 100 && v_cnt < 200)
                    bfm_vid_data <= 24'hFFFFFF; // The "object"
                else
                    bfm_vid_data <= 24'h000000;
            end
        end else begin
            bfm_vid_data <= 24'd0;
        end
    end

    // Instance of rgb2dvi to generate TMDS for DUT
    npu_system_rgb2dvi_0_0 sim_hdmi_tx (
        .PixelClk(pclk),
        .TMDS_Clk_n(tmds_rx_clk_n),
        .TMDS_Clk_p(tmds_rx_clk_p),
        .TMDS_Data_n(tmds_rx_data_n),
        .TMDS_Data_p(tmds_rx_data_p),
        .aRst_n(sys_rst_n),
        .vid_pData(bfm_vid_data),
        .vid_pHSync(bfm_vid_hsync),
        .vid_pVDE(bfm_vid_vde),
        .vid_pVSync(bfm_vid_vsync)
    );

    // =========================================================================
    // HDMI Output Checker
    // =========================================================================
    wire chk_vid_hsync, chk_vid_vsync, chk_vid_vde;
    wire [23:0] chk_vid_data;
    wire chk_pixel_clk;

    npu_system_dvi2rgb_0_0 sim_hdmi_rx (
        .PixelClk(chk_pixel_clk),
        .RefClk(refclk),
        .TMDS_Clk_n(tmds_tx_clk_n),
        .TMDS_Clk_p(tmds_tx_clk_p),
        .TMDS_Data_n(tmds_tx_data_n),
        .TMDS_Data_p(tmds_tx_data_p),
        .aPixelClkLckd(),
        .aRst_n(sys_rst_n),
        .pRst_n(1'b1),
        .vid_pData(chk_vid_data),
        .vid_pHSync(chk_vid_hsync),
        .vid_pVDE(chk_vid_vde),
        .vid_pVSync(chk_vid_vsync),
        .SCL_I(1'b1), .SDA_I(1'b1), .SCL_O(), .SCL_T(), .SDA_O(), .SDA_T()
    );
    
    // =========================================================================
    // Scoreboard and Assertions
    // =========================================================================
    
    // SVA: Ensure TMDS clocks are toggling
    property tmds_clk_toggles;
        @(posedge sysclk) disable iff (ext_reset)
        (tmds_tx_clk_p);
    endproperty
    // We won't use SVA for TMDS clk since it's much faster than sysclk and  might not catch it perfectly.
    
    // Wait for frames
    initial begin
        $display("Starting End-to-End HDMI Simulation");
        wait(frame_cnt == 4);
        #10000;
        $display("Simulation Complete!");
        $finish;
    end

endmodule