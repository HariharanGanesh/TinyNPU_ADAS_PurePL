`timescale 1ns / 1ps
// =============================================================================
// Module: tinynpu_hdmi_top.v
// Project: TinyNPU200 v1.0
//
// SYNTHESIS TOP-LEVEL — PYNQ-Z2 (XC7Z020CLG400-1)
// 100% Pure Programmable Logic (PL). Zero ARM processor. Zero software.
//
// PIPELINE:
//   HDMI RX (dvi2rgb) → pixel-to-AXI adapter
//   → TinyNPU200 (20×8 INT8, 195 MHz)
//   → BBox Extractor → Object Tracker
//   → Hardware OSD Mixer → HDMI TX (rgb2dvi)
//
// CLOCK ARCHITECTURE:
//   sys_pll (MMCM #1):  125MHz → 195 MHz (npu_clk) + 200 MHz (IDELAYCTRL RefClk)
//   pixel_pll (MMCM #2): 195 MHz → 74.286 MHz (vid_pix_clk, 720p)
//
// UPGRADES vs TinyNPU2k200J:
//   - Systolic array: 8×8 → 20×8 (160 DSP48s, ~24.96 GOPS)
//   - Processing element: 2-stage → 3-stage pipeline
//   - Activation: ReLU/Identity/ReLU6 → + LeakyReLU + HardSwish (3-bit sel)
//   - Pooling: MaxPool only → + AvgPool (2-bit mode)
//   - CSR: 20 → 32 registers (self-describing via REG_FEATURE_FLAGS)
//   - vid_locked + tile_count status fed back from HDMI domain to CSR
//
// HDMI RESOLUTION: 720p (1280×720@60Hz, pixel clock = 74.25 MHz)
//   1080p is NOT supported on PYNQ-Z2 PL-only (BRAM line buffer overflow).
//
// XDC NOTES (see tinynpu_pynq200.xdc):
//   - sys_pll MMCM: LOC MMCME2_ADV_X0Y1
//   - rgb2dvi MMCM: LOC MMCME2_ADV_X1Y2
//   - CLOCK_DEDICATED_ROUTE BACKBONE on sys_pll clk_in1 net
// =============================================================================

module tinynpu_hdmi_top (
    input  wire         sys_clk,        // 125 MHz board oscillator (H16)
    input  wire         sys_rst_n,      // BTN0, active-high button — inverted in logic

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
    // sys_pll:   clk_out1 = 195 MHz (NPU), clk_out2 = 200 MHz (IDELAYCTRL)
    // pixel_pll: clk_out1 = 74.286 MHz  (720p pixel clock for rgb2dvi)
    // =========================================================================
    wire clk_195mhz;
    wire clk_200mhz;
    wire pll_locked;

    sys_pll u_pll (
        .clk_in1  (sys_clk),
        .clk_out1 (clk_195mhz),    // 195 MHz NPU clock
        .clk_out2 (clk_200mhz),    // 200 MHz IDELAYCTRL reference
        .locked   (pll_locked)
    );

    wire vid_pix_clk;
    wire pixel_pll_locked;

    pixel_pll u_pixel_pll (
        .clk_in1  (clk_195mhz),    // 195 MHz input
        .clk_out1 (vid_pix_clk),   // 74.286 MHz output for 720p
        .locked   (pixel_pll_locked)
    );

    wire npu_clk = clk_195mhz;
    // Reset: active-low, requires both PLLs locked, inverted button (BTN0 = active-high)
    wire rst_n   = (~sys_rst_n) & pll_locked & pixel_pll_locked;

    // =========================================================================
    // HDMI RX: dvi2rgb — Decode HDMI IN TMDS into 24-bit RGB pixels
    // Uses Digilent pynq_dvi_rx IP (dvi2rgb v2.0)
    // =========================================================================
    wire [23:0] vid_rgb;        // Raw 24-bit RGB from HDMI source
    wire        vid_de;         // Data Enable (high during active video pixels)
    wire        vid_hsync;      // Horizontal Sync (from HDMI source)
    wire        vid_vsync;      // Vertical Sync (from HDMI source)
    wire        dvi_locked;     // HDMI lock indicator (1 = valid lock on input)

    pynq_dvi_rx u_dvi2rgb (
        .TMDS_Clk_p  (hdmi_rx_clk_p),
        .TMDS_Clk_n  (hdmi_rx_clk_n),
        .TMDS_Data_p (hdmi_rx_data_p),
        .TMDS_Data_n (hdmi_rx_data_n),
        .RefClk      (clk_200mhz),     // IDELAYCTRL reference (must be 200 MHz)
        .aRst        (~rst_n),          // Active-high async reset
        .pRst        (1'b0),            // Fix Vivado opt_design error: tie unused reset to 0
        .SDA_I       (1'b1),            // Tie off unused I2C
        .SCL_I       (1'b1),            // Tie off unused I2C
        .vid_pData   (vid_rgb),
        .vid_pVDE    (vid_de),
        .vid_pHSync  (vid_hsync),
        .vid_pVSync  (vid_vsync),
        .PixelClk    (),                // Recovered pixel clock (unused; we use pixel_pll)
        .pLocked     (dvi_locked)
    );

    // =========================================================================
    // Pixel-to-AXI-Stream Adapter
    // Converts the pixel-clock-domain RGB + DE/HSYNC signals into a
    // 195 MHz domain AXI4-Stream for TinyNPU200.
    //
    // CDC: vid_rgb, vid_de, vid_hsync, vid_vsync are in the recovered pixel
    // clock domain. We use a 2-FF synchronizer + edge-detect chain.
    // This is safe because:
    //   (a) pixel data changes every pixel clock cycle (>5 ns period)
    //   (b) at 195 MHz the 2-FF chain resolves within 2 cycles (<11 ns)
    //   (c) the NPU processes tiles, so occasional pixel slip is acceptable
    // For production use a proper async FIFO (cdc_async_fifo.v included).
    // =========================================================================
    reg [23:0]  vid_rgb_r1,   vid_rgb_r2;
    reg         vid_de_r1,    vid_de_r2;
    reg         vid_hsync_r1, vid_hsync_r2, vid_hsync_r3;
    reg         vid_vsync_r1, vid_vsync_r2;

    always @(posedge npu_clk or negedge rst_n) begin
        if (!rst_n) begin
            vid_rgb_r1   <= 0; vid_rgb_r2   <= 0;
            vid_de_r1    <= 0; vid_de_r2    <= 0;
            vid_hsync_r1 <= 0; vid_hsync_r2 <= 0; vid_hsync_r3 <= 0;
            vid_vsync_r1 <= 0; vid_vsync_r2 <= 0;
        end else begin
            vid_rgb_r1   <= vid_rgb;    vid_rgb_r2   <= vid_rgb_r1;
            vid_de_r1    <= vid_de;     vid_de_r2    <= vid_de_r1;
            vid_hsync_r1 <= vid_hsync;  vid_hsync_r2 <= vid_hsync_r1;
                                        vid_hsync_r3 <= vid_hsync_r2;
            vid_vsync_r1 <= vid_vsync;  vid_vsync_r2 <= vid_vsync_r1;
        end
    end

    // AXI-Stream: pack RGB into 32-bit word (8'h00 + R + G + B)
    // tvalid = data enable (active pixel)
    // tlast  = falling edge of hsync (end of line)
    wire [31:0] s_axis_tdata;
    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire        s_axis_tlast;

    assign s_axis_tdata  = {8'h00, vid_rgb_r2};
    assign s_axis_tvalid = vid_de_r2;
    assign s_axis_tlast  = (!vid_hsync_r2 && vid_hsync_r3); // Falling edge of hsync

    // =========================================================================
    // AXI-Lite Interface — Tied off for pure PL operation
    // All CSR registers use their reset values (TinyNPU200 feature flags apply)
    // In a future PS-connected design, connect to PS GP0 AXI master.
    // =========================================================================
    wire [31:0] awaddr  = 32'h0; wire awvalid = 1'b0; wire awready_nc;
    wire [31:0] wdata   = 32'h0; wire wvalid  = 1'b0; wire wready_nc;
    wire [1:0]  bresp_nc;        wire bvalid_nc;       wire bready  = 1'b1;
    wire [31:0] araddr  = 32'h0; wire arvalid = 1'b0; wire arready_nc;
    wire [31:0] rdata_nc;        wire rvalid_nc;       wire rready  = 1'b1;

    // =========================================================================
    // TinyNPU200 Core (20×8, 195 MHz)
    // =========================================================================
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire        m_axis_tlast;

    // Tile counter: incremented by NPU controller, reported via CSR
    reg [31:0] tile_count;
    always @(posedge npu_clk or negedge rst_n) begin
        if (!rst_n) tile_count <= 32'h0;
        else if (m_axis_tvalid && m_axis_tlast) tile_count <= tile_count + 1;
    end

    tinynpu_top #(
        .DATA_WIDTH       (8),
        .ARRAY_ROWS       (20),    // TinyNPU200: 20 rows
        .ARRAY_COLS       (8),
        .ACCUM_WIDTH      (32),
        .BUFFER_DEPTH     (1024),
        .BUFFER_ADDR_WIDTH(10),
        .MAX_WIDTH        (128),
        .TILE_SIZE        (160)    // 20×8 = 160 per tile
    ) u_npu (
        .clk    (npu_clk),
        .rst_n  (rst_n),

        // AXI-Lite (tied off)
        .s_axi_awaddr  (awaddr),   .s_axi_awprot  (3'b0),
        .s_axi_awvalid (awvalid),  .s_axi_awready (awready_nc),
        .s_axi_wdata   (wdata),    .s_axi_wstrb   (4'hF),
        .s_axi_wvalid  (wvalid),   .s_axi_wready  (wready_nc),
        .s_axi_bresp   (bresp_nc), .s_axi_bvalid  (bvalid_nc),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),   .s_axi_arprot  (3'b0),
        .s_axi_arvalid (arvalid),  .s_axi_arready (arready_nc),
        .s_axi_rdata   (rdata_nc), .s_axi_rresp   (),
        .s_axi_rvalid  (rvalid_nc), .s_axi_rready (rready),

        // AXI-Full Master (DMA — not used in HDMI passthrough mode; tie off)
        .m_axi_awaddr  (), .m_axi_awlen  (), .m_axi_awsize  (),
        .m_axi_awburst (), .m_axi_awvalid(), .m_axi_awready (1'b0),
        .m_axi_wdata   (), .m_axi_wstrb  (), .m_axi_wlast   (),
        .m_axi_wvalid  (), .m_axi_wready (1'b0),
        .m_axi_bresp   (2'b0), .m_axi_bvalid (1'b0), .m_axi_bready (),
        .m_axi_araddr  (), .m_axi_arlen  (), .m_axi_arsize  (),
        .m_axi_arburst (), .m_axi_arvalid(), .m_axi_arready (1'b0),
        .m_axi_rdata   (32'h0), .m_axi_rresp (2'b0),
        .m_axi_rlast   (1'b0), .m_axi_rvalid(1'b0), .m_axi_rready (),

        // AXI-Stream In (from pixel adapter)
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),

        // AXI-Stream Out (detection results)
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast),

        // HDMI status feedback to CSR
        .vid_locked_in (dvi_locked),
        .tile_count_in (tile_count),

        .interrupt     ()
    );

    assign m_axis_tready = 1'b1; // Always accept NPU output in HDMI mode

    // =========================================================================
    // BBox Extractor: Parse m_axis output into {xmin, ymin, xmax, ymax}
    // Protocol: NPU emits [X_min[11:0], Y_min[11:0]] word then
    //           [X_max[11:0], Y_max[11:0]] word, separated by tlast.
    // =========================================================================
    reg  [31:0] bbox_word0;
    reg         bbox_word0_valid;
    reg         bbox_valid_r;
    reg  [11:0] bbox_xmin_r, bbox_ymin_r, bbox_xmax_r, bbox_ymax_r;

    always @(posedge npu_clk or negedge rst_n) begin
        if (!rst_n) begin
            bbox_word0       <= 0;
            bbox_word0_valid <= 1'b0;
            bbox_valid_r     <= 1'b0;
            bbox_xmin_r <= 0; bbox_ymin_r <= 0;
            bbox_xmax_r <= 0; bbox_ymax_r <= 0;
        end else begin
            bbox_valid_r <= 1'b0;
            if (m_axis_tvalid) begin
                if (!bbox_word0_valid) begin
                    bbox_word0       <= m_axis_tdata;
                    bbox_word0_valid <= 1'b1;
                end else begin
                    bbox_xmin_r      <= bbox_word0[27:16];
                    bbox_ymin_r      <= bbox_word0[11:0];
                    bbox_xmax_r      <= m_axis_tdata[27:16];
                    bbox_ymax_r      <= m_axis_tdata[11:0];
                    bbox_valid_r     <= 1'b1;
                    bbox_word0_valid <= 1'b0;
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
        .clk            (npu_clk),
        .rst_n          (rst_n),
        .bbox_valid     (bbox_valid_r),
        .bbox_xmin      (bbox_xmin_r),
        .bbox_ymin      (bbox_ymin_r),
        .bbox_xmax      (bbox_xmax_r),
        .bbox_ymax      (bbox_ymax_r),
        .target_locked  (target_locked),
        .read_idx       (track_idx),
        .track_valid    (track_valid),
        .track_x        (track_x),
        .track_y        (track_y),
        .track_distance (track_dist),
        .track_speed    (track_speed)
    );

    // =========================================================================
    // Font ROM
    // =========================================================================
    wire [7:0] char_ascii;
    wire [2:0] font_row, font_col;
    wire       font_pixel;

    font_rom u_font (
        .clk       (npu_clk),
        .char_ascii(char_ascii),
        .row       (font_row),
        .col       (font_col),
        .pixel_on  (font_pixel)
    );

    // =========================================================================
    // Hardware OSD Mixer
    // Draws tracking boxes, confidence scores, and system info overlay.
    // All video signals are in the 195 MHz NPU domain (synchronized above).
    // =========================================================================
    wire [23:0] osd_vid_data;
    wire        osd_hsync, osd_vsync, osd_de;

    hardware_osd_mixer u_mixer (
        .clk           (npu_clk),
        .rst_n         (rst_n),
        .vid_in_data   (vid_rgb_r2),
        .vid_in_hsync  (vid_hsync_r2),
        .vid_in_vsync  (vid_vsync_r2),
        .vid_in_de     (vid_de_r2),
        .vid_out_data  (osd_vid_data),
        .vid_out_hsync (osd_hsync),
        .vid_out_vsync (osd_vsync),
        .vid_out_de    (osd_de),
        .track_idx     (track_idx),
        .track_valid   (track_valid),
        .track_x       (track_x),
        .track_y       (track_y),
        .track_distance(track_dist),
        .track_speed   (track_speed),
        .char_ascii    (char_ascii),
        .font_row      (font_row),
        .font_col      (font_col),
        .font_pixel    (font_pixel)
    );

    // =========================================================================
    // HDMI TX: rgb2dvi — Encode 24-bit RGB back to TMDS for HDMI OUT
    // Uses Digilent pynq_dvi_tx IP (rgb2dvi v2.0)
    // PixelClk = vid_pix_clk = 74.286 MHz from pixel_pll (720p).
    // OSD signals are in 195 MHz domain.
    // CDC: The rgb2dvi IP internally re-clocks input data on PixelClk.
    //      Vivado's SmartConnect FIFO inside rgb2dvi bridges the domains.
    // =========================================================================
    pynq_dvi_tx u_rgb2dvi (
        .PixelClk   (vid_pix_clk),     // 74.286 MHz for 720p
        .aRst       (~rst_n),           // Active-high async reset
        .vid_pData  (osd_vid_data),     // 24-bit RGB (from 195 MHz OSD)
        .vid_pVDE   (osd_de),
        .vid_pHSync (osd_hsync),
        .vid_pVSync (osd_vsync),
        .TMDS_Clk_p (hdmi_tx_clk_p),
        .TMDS_Clk_n (hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_data_p),
        .TMDS_Data_n(hdmi_tx_data_n)
    );

    // =========================================================================
    // Status LEDs
    // [0] = HDMI RX lock   [1] = PLL locked
    // [2] = Target locked  [3] = NPU active (tile_count[0])
    // =========================================================================
    assign led[0] = dvi_locked;
    assign led[1] = pll_locked & pixel_pll_locked;
    assign led[2] = target_locked;
    assign led[3] = tile_count[0]; // Blinks at half the tile rate

endmodule
