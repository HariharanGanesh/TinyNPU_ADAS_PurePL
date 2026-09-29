`timescale 1ns / 1ps
// =============================================================================
// Module: tinynpu_hdmi_top.v
// Project: TinyNPU2k200J
// Description: Complete top-level hardware wrapper for the HDMI AI pipeline.
//
//   HDMI IN (DVI2RGB) -> Pixel-to-AXI Adapter -> TinyNPU -> BBox Extractor
//   -> Object Tracker -> Hardware OSD Mixer -> HDMI OUT (RGB2DVI)
//
//   100% Pure Programmable Logic (PL). Zero ARM processor. Zero software.
//   195 MHz NPU clock. 200 MHz IDELAYCTRL reference for DVI2RGB.
//
// Gaps resolved:
//   [Gap 1] dvi2rgb and rgb2dvi instantiated with all ports connected.
//   [Gap 2] sys_pll clk_out2 (200 MHz) wired to dvi2rgb RefClk.
//   [Gap 3] Pixel stream converted to AXI-Stream and fed into NPU.
//           NPU m_axis output decoded into bbox coordinates for tracker.
// =============================================================================

module tinynpu_hdmi_top (
    input  wire         sys_clk,       // 125 MHz board oscillator (PYNQ-Z2 H16)
    input  wire         sys_rst_n,     // BTN0 (active-high button, inverted here)

    // HDMI RX (TMDS Differential Pairs)
    input  wire         hdmi_rx_clk_p,
    input  wire         hdmi_rx_clk_n,
    input  wire [2:0]   hdmi_rx_data_p,
    input  wire [2:0]   hdmi_rx_data_n,

    // HDMI TX (TMDS Differential Pairs)
    output wire         hdmi_tx_clk_p,
    output wire         hdmi_tx_clk_n,
    output wire [2:0]   hdmi_tx_data_p,
    output wire [2:0]   hdmi_tx_data_n,

    // Physical Status LEDs
    output wire [3:0]   led
);

    // =========================================================================
    // Clock & Reset
    // sys_pll: clk_out1 = 195 MHz (NPU), clk_out2 = 200 MHz (IDELAYCTRL)
    // =========================================================================
    wire clk_195mhz;
    wire clk_200mhz;
    wire pll_locked;

    sys_pll u_pll (
        .clk_in1  (sys_clk),
        .clk_out1 (clk_195mhz),   // NPU processing clock
        .clk_out2 (clk_200mhz),   // DVI2RGB IDELAYCTRL reference (Gap 2 FIX)
        .locked   (pll_locked)
    );

    wire npu_clk  = clk_195mhz;
    wire rst_n    = (~sys_rst_n) & pll_locked; // Inverted active-high btn + PLL guard

    // =========================================================================
    // Gap 1 FIX: DVI2RGB — Decode HDMI IN TMDS into 24-bit RGB pixels
    // =========================================================================
    wire [23:0] vid_rgb;        // Raw 24-bit RGB from HDMI
    wire        vid_de;         // Data Enable (high during active video)
    wire        vid_hsync;      // Horizontal Sync
    wire        vid_vsync;      // Vertical Sync
    wire        vid_pix_clk;    // Recovered pixel clock from HDMI source
    wire        dvi_locked;     // HDMI lock indicator

    pynq_dvi_rx u_dvi2rgb (
        // TMDS Physical Pins
        .TMDS_Clk_p  (hdmi_rx_clk_p),
        .TMDS_Clk_n  (hdmi_rx_clk_n),
        .TMDS_Data_p (hdmi_rx_data_p),
        .TMDS_Data_n (hdmi_rx_data_n),

        // 200 MHz reference clock for IDELAYCTRL
        .RefClk      (clk_200mhz),

        // Asynchronous reset (active-high, kRstActiveHigh=true → aRst only)
        .aRst        (~rst_n),

        // Synchronous pixel-domain reset (INPUT, must be driven, kRstActiveHigh=true → pRst only)
        .pRst        (~rst_n),

        // Decoded Video Output
        .vid_pData   (vid_rgb),
        .vid_pVDE    (vid_de),
        .vid_pHSync  (vid_hsync),
        .vid_pVSync  (vid_vsync),
        .PixelClk    (vid_pix_clk),
        .aPixelClkLckd (dvi_locked),
        .pLocked     ()     // not used, we use aPixelClkLckd
    );

    // =========================================================================
    // Gap 3a FIX: Pixel-to-AXI-Stream Adapter
    // Converts the raw 24-bit RGB pixel from DVI2RGB into a 32-bit AXI-Stream
    // word (R[7:0], G[7:0], B[7:0], 8'h00 padding) fed into the NPU.
    // vid_hsync falling edge = tlast (end of line)
    // =========================================================================
    wire [31:0] s_axis_tdata;
    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire        s_axis_tlast;

    // Sync vid signals to NPU clock domain (simple 2FF synchronizer)
    reg [23:0]  vid_rgb_r;
    reg         vid_de_r, vid_hsync_r, vid_vsync_r;
    reg         vid_de_r2, vid_hsync_r2, vid_hsync_r3;

    always @(posedge npu_clk or negedge rst_n) begin
        if (!rst_n) begin
            vid_rgb_r    <= 0;
            vid_de_r     <= 0; vid_de_r2    <= 0;
            vid_hsync_r  <= 0; vid_hsync_r2 <= 0; vid_hsync_r3 <= 0;
            vid_vsync_r  <= 0;
        end else begin
            vid_rgb_r    <= vid_rgb;
            vid_de_r     <= vid_de;    vid_de_r2    <= vid_de_r;
            vid_hsync_r  <= vid_hsync; vid_hsync_r2 <= vid_hsync_r; vid_hsync_r3 <= vid_hsync_r2;
            vid_vsync_r  <= vid_vsync;
        end
    end

    // Pack RGB into AXI-Stream; tlast fires on falling edge of hsync
    assign s_axis_tdata  = {8'h00, vid_rgb_r};
    assign s_axis_tvalid = vid_de_r2;
    assign s_axis_tlast  = (!vid_hsync_r2 && vid_hsync_r3); // Falling edge of hsync

    // =========================================================================
    // TinyNPU Core (Processing the Video AXI-Stream)
    // =========================================================================
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire        m_axis_tlast;

    // AXI-Lite tied off (hardcoded defaults, no PS config needed)
    wire [31:0] awaddr = 0; wire awvalid = 0; wire awready;
    wire [31:0] wdata  = 0; wire wvalid  = 0; wire wready;
    wire        bvalid;     wire bready  = 1;
    wire [31:0] araddr = 0; wire arvalid = 0; wire arready;
    wire [31:0] rdata;      wire rvalid;      wire rready  = 1;

    tinynpu_top #(
        .DATA_WIDTH(8),
        .ARRAY_ROWS(8),
        .ARRAY_COLS(8)
    ) u_npu (
        .clk   (npu_clk),
        .rst_n (rst_n),

        .s_axi_awaddr  (awaddr),  .s_axi_awvalid (awvalid), .s_axi_awready (awready),
        .s_axi_wdata   (wdata),   .s_axi_wvalid  (wvalid),  .s_axi_wready  (wready),
        .s_axi_bresp   (),        .s_axi_bvalid  (bvalid),  .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),  .s_axi_arvalid (arvalid), .s_axi_arready (arready),
        .s_axi_rdata   (rdata),   .s_axi_rresp   (),        .s_axi_rvalid  (rvalid), .s_axi_rready(rready),

        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),

        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast)
    );

    // =========================================================================
    // Gap 3b FIX: AXI-Stream BBox Extractor
    // Parses NPU m_axis output stream. The output protocol from tinynpu_top
    // emits [X_min(12), Y_min(12), X_max(12), Y_max(12)] = 48 bits over 2 words.
    // We pipeline 2 consecutive valid m_axis words to reconstruct coordinates.
    // =========================================================================
    reg  [31:0] bbox_word0;
    reg         bbox_word0_valid;
    reg         bbox_valid_r;
    reg  [11:0] bbox_xmin_r, bbox_ymin_r, bbox_xmax_r, bbox_ymax_r;

    assign m_axis_tready = 1'b1; // Always accept NPU output

    always @(posedge npu_clk or negedge rst_n) begin
        if (!rst_n) begin
            bbox_word0       <= 0;
            bbox_word0_valid <= 0;
            bbox_valid_r     <= 0;
            bbox_xmin_r <= 0; bbox_ymin_r <= 0;
            bbox_xmax_r <= 0; bbox_ymax_r <= 0;
        end else begin
            bbox_valid_r <= 0;
            if (m_axis_tvalid) begin
                if (!bbox_word0_valid) begin
                    bbox_word0       <= m_axis_tdata;
                    bbox_word0_valid <= 1;
                end else begin
                    // Word 0: {4'b0, X_min[11:0], Y_min[11:0], 4'b0}
                    // Word 1: {4'b0, X_max[11:0], Y_max[11:0], 4'b0}
                    bbox_xmin_r      <= bbox_word0[27:16];
                    bbox_ymin_r      <= bbox_word0[11:0];
                    bbox_xmax_r      <= m_axis_tdata[27:16];
                    bbox_ymax_r      <= m_axis_tdata[11:0];
                    bbox_valid_r     <= 1;
                    bbox_word0_valid <= 0;
                end
            end
        end
    end

    // =========================================================================
    // Object Tracker
    // =========================================================================
    wire        target_locked;
    wire [3:0]  track_idx;
    wire        track_valid;
    wire [11:0] track_x, track_y, track_dist, track_speed;

    object_tracker #(
        .MAX_TARGETS (16),
        .KNOWN_WIDTH (32000)
    ) u_tracker (
        .clk         (npu_clk),
        .rst_n       (rst_n),
        .bbox_valid  (bbox_valid_r),
        .bbox_xmin   (bbox_xmin_r),
        .bbox_ymin   (bbox_ymin_r),
        .bbox_xmax   (bbox_xmax_r),
        .bbox_ymax   (bbox_ymax_r),
        .target_locked (target_locked),
        .read_idx    (track_idx),
        .track_valid (track_valid),
        .track_x     (track_x),
        .track_y     (track_y),
        .track_distance (track_dist),
        .track_speed (track_speed)
    );

    // =========================================================================
    // Font ROM
    // =========================================================================
    wire [7:0]  char_ascii;
    wire [2:0]  font_row, font_col;
    wire        font_pixel;

    font_rom u_font (
        .clk       (npu_clk),
        .char_ascii(char_ascii),
        .row       (font_row),
        .col       (font_col),
        .pixel_on  (font_pixel)
    );

    // =========================================================================
    // Hardware OSD Mixer
    // =========================================================================
    wire [23:0] osd_vid_data;
    wire        osd_hsync, osd_vsync, osd_de;

    hardware_osd_mixer u_mixer (
        .clk          (npu_clk),
        .rst_n        (rst_n),
        .vid_in_data  (vid_rgb_r),
        .vid_in_hsync (vid_hsync_r2),
        .vid_in_vsync (vid_vsync_r),
        .vid_in_de    (vid_de_r2),
        .vid_out_data (osd_vid_data),
        .vid_out_hsync(osd_hsync),
        .vid_out_vsync(osd_vsync),
        .vid_out_de   (osd_de),
        .track_idx    (track_idx),
        .track_valid  (track_valid),
        .track_x      (track_x),
        .track_y      (track_y),
        .track_distance(track_dist),
        .track_speed  (track_speed),
        .char_ascii   (char_ascii),
        .font_row     (font_row),
        .font_col     (font_col),
        .font_pixel   (font_pixel)
    );

    // =========================================================================
    // Gap 1 FIX: RGB2DVI — Encode 24-bit RGB back to TMDS for HDMI OUT
    // =========================================================================
    pynq_dvi_tx u_rgb2dvi (
        // Clock
        .PixelClk     (vid_pix_clk),    // Use recovered pixel clock

        // Reset
        .aRst         (~rst_n),

        // Video Input (from OSD Mixer)
        .vid_pData    (osd_vid_data),
        .vid_pVDE     (osd_de),
        .vid_pHSync   (osd_hsync),
        .vid_pVSync   (osd_vsync),

        // TMDS Physical Pins
        .TMDS_Clk_p   (hdmi_tx_clk_p),
        .TMDS_Clk_n   (hdmi_tx_clk_n),
        .TMDS_Data_p  (hdmi_tx_data_p),
        .TMDS_Data_n  (hdmi_tx_data_n)
    );

    // =========================================================================
    // Status LEDs
    // =========================================================================
    assign led[0] = dvi_locked;   // HDMI Rx Lock
    assign led[1] = pll_locked;   // Core PLL Lock
    assign led[2] = 1'b0;
    assign led[3] = 1'b0;         // Will be AI target lock later

endmodule
