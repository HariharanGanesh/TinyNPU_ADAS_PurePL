import os

axi_path = "IP/TinyNPU200/src/axi4_lite_slave.v"
with open(axi_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "AWREADY / WREADY / ARREADY always accept immediately" in line:
        skip = True
        new_lines.append("""
    // =========================================================================
    // AXI4-Lite Handshake Registers
    // =========================================================================
    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [1:0] axi_rresp;

    assign s_awready = axi_awready;
    assign s_wready  = axi_wready;
    assign s_bresp   = axi_bresp;
    assign s_bvalid  = axi_bvalid;
    assign s_arready = axi_arready;
    assign s_rresp   = axi_rresp;

    // AWREADY and AWADDR
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && s_awvalid && s_wvalid) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= s_awaddr;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // WREADY
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && s_wvalid && s_awvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // BVALID and BRESP
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (axi_awready && s_awvalid && ~axi_bvalid && axi_wready && s_wvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00;
            end else if (s_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    wire slv_reg_wren = axi_wready && s_wvalid && axi_awready && s_awvalid;

    // =========================================================================
    // AXI4-Lite Read Handshake
    // =========================================================================
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 0;
        end else begin
            if (~axi_arready && s_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr  <= s_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    wire slv_reg_rden = axi_arready & s_arvalid & ~s_rvalid;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_rvalid <= 1'b0;
            axi_rresp <= 2'b00;
        end else begin
            if (slv_reg_rden) begin
                s_rvalid <= 1'b1;
                axi_rresp <= 2'b00;
            end else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_rdata <= 0;
        end else begin
            if (slv_reg_rden) begin
                case (axi_araddr[7:0])
                    ADDR_CTRL:            s_rdata <= reg_ctrl;
                    ADDR_STATUS:          s_rdata <= {28'b0, status_error, status_done, status_busy, status_idle};
                    ADDR_WEIGHT_BASE:     s_rdata <= reg_weight_base;
                    ADDR_ACT_BASE:        s_rdata <= reg_act_base;
                    ADDR_OUT_BASE:        s_rdata <= reg_out_base;
                    ADDR_LAYER_CFG_0:     s_rdata <= reg_layer_cfg0;
                    ADDR_LAYER_CFG_1:     s_rdata <= reg_layer_cfg1;
                    ADDR_LAYER_CFG_2:     s_rdata <= reg_layer_cfg2;
                    ADDR_PERF_CYCLE_LO:   s_rdata <= perf_cycle_count[31:0];
                    ADDR_PERF_CYCLE_HI:   s_rdata <= perf_cycle_count[63:32];
                    ADDR_IRQ_CTRL:        s_rdata <= reg_irq_ctrl;
                    ADDR_M0_CFG:          s_rdata <= reg_m0;
                    ADDR_SHIFT_CFG:       s_rdata <= reg_n_shift;
                    ADDR_BIAS_CFG:        s_rdata <= reg_bias;
                    ADDR_PERF_COMPUTE_LO: s_rdata <= perf_compute_count[31:0];
                    ADDR_PERF_COMPUTE_HI: s_rdata <= perf_compute_count[63:32];
                    ADDR_PERF_DMA_STALL:  s_rdata <= perf_dma_stall_count;
                    ADDR_PERF_OUT_STALL:  s_rdata <= perf_out_stall_count;
                    ADDR_CONF_THRESHOLD:  s_rdata <= reg_conf_threshold;
                    ADDR_CROP_XY:         s_rdata <= reg_crop_xy;
                    ADDR_CROP_WH:         s_rdata <= reg_crop_wh;
                    ADDR_STRIDE_SEL:      s_rdata <= reg_stride_sel;
                    ADDR_ACT_EXT:         s_rdata <= reg_act_ext;
                    ADDR_POOL_MODE:       s_rdata <= reg_pool_mode;
                    ADDR_ARRAY_ROWS:      s_rdata <= reg_array_rows;
                    ADDR_INPUT_FMT:       s_rdata <= reg_input_fmt;
                    ADDR_FRAME_W:         s_rdata <= reg_frame_w;
                    ADDR_FRAME_H:         s_rdata <= reg_frame_h;
                    ADDR_NUM_TILES:       s_rdata <= reg_num_tiles;
                    ADDR_VID_LOCKED:      s_rdata <= {31'b0, vid_locked};
                    ADDR_TILE_COUNT:      s_rdata <= tile_count;
                    ADDR_VERSION:         s_rdata <= 32'h02000001;
                    ADDR_FEATURE_FLAGS:   s_rdata <= 32'h0000007F;
                    default:              s_rdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end
""")
    elif skip and "Output Mapping" in line:
        skip = False
        new_lines.append(line)
    elif not skip:
        # Before 'Output Mapping', we also have the CSR Write Logic. Let's just fix it if it's there.
        # Actually it's easier to just retain the original Write logic and just replace the write condition!
        pass

# Oh wait, the CSR Write Logic is lost if I skip until Output Mapping!
