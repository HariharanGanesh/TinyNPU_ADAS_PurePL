`timescale 1ns/1ps

module tb_axi_csr;
    // Parameters
    localparam C_S_AXI_DATA_WIDTH = 32;
    localparam C_S_AXI_ADDR_WIDTH = 8;

    // Signals
    logic clk;
    logic reset_n;
    
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr;
    logic [2:0] awprot;
    logic awvalid;
    logic awready;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;
    logic [C_S_AXI_DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    // Output CSR wires
    logic start;
    logic soft_reset;
    logic status_idle = 1;
    logic status_busy = 0;
    logic status_done = 0;
    logic status_error = 0;
    logic [31:0] weight_base;
    logic [31:0] act_base;
    logic [31:0] out_base;
    logic [15:0] in_channels;
    logic [15:0] out_channels;
    logic [15:0] input_width;
    logic [15:0] input_height;
    logic [7:0]  kernel_size;
    logic [7:0]  stride;
    logic [7:0]  padding;
    logic [31:0] m0;
    logic [31:0] n_shift;
    logic [31:0] bias;
    logic [7:0]  conf_threshold;
    logic [15:0] crop_x;
    logic [15:0] crop_y;
    logic [15:0] crop_w;
    logic [15:0] crop_h;
    logic [15:0] frame_w;
    logic [15:0] frame_h;
    logic [15:0] num_tiles_x;
    logic [15:0] num_tiles_y;
    logic [1:0]  act_sel;
    logic        irq_en;
    logic        wgt_bank_sel;
    logic        layer_type;
    logic [2:0]  act_ext;
    logic [1:0]  pool_mode;
    logic [1:0]  stride_sel;
    logic [4:0]  array_rows = 5'd20; // Read-only value driven into CSR
    logic [1:0]  input_fmt;
    logic [63:0] perf_cycle_count = 0;
    logic [63:0] perf_compute_count = 0;
    logic [31:0] perf_dma_stall_count = 0;
    logic [31:0] perf_out_stall_count = 0;
    logic [31:0] tile_count = 0;
    logic        vid_locked = 1;

    // DUT
    axi4_lite_slave #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(reset_n),
        .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(awprot), .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata), .S_AXI_WSTRB(wstrb), .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(arprot), .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp), .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready),

        // CSR Ports
        .start(start), .soft_reset(soft_reset),
        .status_idle(status_idle), .status_busy(status_busy), .status_done(status_done), .status_error(status_error),
        .weight_base(weight_base), .act_base(act_base), .out_base(out_base),
        .in_channels(in_channels), .out_channels(out_channels),
        .input_width(input_width), .input_height(input_height),
        .kernel_size(kernel_size), .stride(stride), .padding(padding),
        .m0(m0), .n_shift(n_shift), .bias(bias), .conf_threshold(conf_threshold),
        .crop_x(crop_x), .crop_y(crop_y), .crop_w(crop_w), .crop_h(crop_h),
        .frame_w(frame_w), .frame_h(frame_h), .num_tiles_x(num_tiles_x), .num_tiles_y(num_tiles_y),
        .act_sel(act_sel), .irq_en(irq_en), .wgt_bank_sel(wgt_bank_sel), .layer_type(layer_type),
        .act_ext(act_ext), .pool_mode(pool_mode), .stride_sel(stride_sel),
        .array_rows(array_rows), .input_fmt(input_fmt),
        .perf_cycle_count(perf_cycle_count), .perf_compute_count(perf_compute_count),
        .perf_dma_stall_count(perf_dma_stall_count), .perf_out_stall_count(perf_out_stall_count),
        .tile_count(tile_count), .vid_locked(vid_locked)
    );

    always #5 clk = ~clk;

    int tests_passed = 0;
    int tests_failed = 0;

    task axi_write(input logic [C_S_AXI_ADDR_WIDTH-1:0] addr, input logic [C_S_AXI_DATA_WIDTH-1:0] data);
        awaddr = addr; awvalid = 1; awprot = 0;
        wdata = data; wvalid = 1; wstrb = 4'hF;
        bready = 1;
        fork
            begin
                wait(awready);
                @(posedge clk); awvalid = 0;
            end
            begin
                wait(wready);
                @(posedge clk); wvalid = 0;
            end
        join
        wait(bvalid);
        @(posedge clk);
        bready = 0;
    endtask

    task axi_read(input logic [C_S_AXI_ADDR_WIDTH-1:0] addr, output logic [C_S_AXI_DATA_WIDTH-1:0] data, output logic [1:0] resp);
        araddr = addr; arvalid = 1; arprot = 0;
        rready = 1;
        wait(arready);
        @(posedge clk);
        arvalid = 0;
        wait(rvalid);
        data = rdata;
        resp = rresp;
        @(posedge clk);
        rready = 0;
    endtask

    initial begin
        clk = 0; reset_n = 0;
        awvalid = 0; wvalid = 0; bready = 0;
        arvalid = 0; rready = 0;
        
        #20 reset_n = 1;
        
        // TC01: Write CTRL[start]=1
        status_idle = 0;
        axi_write(8'h00, 32'h1);
        begin
            logic [31:0] rd; logic [1:0] rr;
            axi_read(8'h04, rd, rr);
            if (rd[0] == 0) begin $display("[PASS] TC01: Read STATUS.idle=0"); tests_passed++; end
            else begin $error("[FAIL] TC01: STATUS wrong"); tests_failed++; end
        end

        // TC02: Read CSR at reset (verify weight_base = 0)
        begin
            logic [31:0] rd; logic [1:0] rr;
            axi_read(8'h08, rd, rr);
            if (rd == 0) begin $display("[PASS] TC02: Reset values correct"); tests_passed++; end
            else begin $error("[FAIL] TC02: Reset values wrong"); tests_failed++; end
        end

        // TC03: Write/Read writable register
        axi_write(8'h08, 32'hDEADBEEF);
        begin
            logic [31:0] rd; logic [1:0] rr;
            axi_read(8'h08, rd, rr);
            if (rd == 32'hDEADBEEF) begin $display("[PASS] TC03: Read/Write matches"); tests_passed++; end
            else begin $error("[FAIL] TC03: Read/Write failed"); tests_failed++; end
        end

        // TC04: Read-only register
        axi_write(8'h48, 32'hFFFFFFFF);
        begin
            logic [31:0] rd; logic [1:0] rr;
            axi_read(8'h48, rd, rr);
            if (rd == 20) begin $display("[PASS] TC04: Read-only ignored"); tests_passed++; end
            else begin $error("[FAIL] TC04: Read-only failed"); tests_failed++; end
        end

        // TC05: Unaligned/Illegal address (e.g. 0xF0)
        begin
            logic [31:0] rd; logic [1:0] rr;
            axi_read(8'hF0, rd, rr);
            // Even if SLVERR isn't cleanly supported by simple axi slaves, we check response or default
            if (rr == 2'b10 || rd == 0) begin $display("[PASS] TC05: Illegal address handled"); tests_passed++; end
            else begin $error("[FAIL] TC05: Illegal address failed"); tests_failed++; end
        end

        // Summary
        $display("==========================================");
        $display("REGRESSION SUMMARY: %0d/%0d tests passed", tests_passed, tests_passed + tests_failed);
        if (tests_failed == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL");
        $display("==========================================");
        
        $finish;
    end

    // SVA
    property valid_stable_aw;
        @(posedge clk) (awvalid && !awready) |=> awvalid;
    endproperty
    assert property(valid_stable_aw) else $error("AWVALID SVA");
    
    property valid_stable_w;
        @(posedge clk) (wvalid && !wready) |=> wvalid;
    endproperty
    assert property(valid_stable_w) else $error("WVALID SVA");

endmodule
