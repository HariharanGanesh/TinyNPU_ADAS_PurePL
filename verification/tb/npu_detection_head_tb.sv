`timescale 1ns/1ps

module npu_detection_head_tb;
    
    // Parameters
    parameter NUM_CLASSES = 200;
    parameter REG_MAX     = 16;
    parameter BINS        = REG_MAX + 1;
    parameter DATA_WIDTH  = 8;
    parameter ADDR_WIDTH  = 10;
    
    // Signals
    logic clk;
    logic rst_n;
    logic clear_frame;
    logic [ADDR_WIDTH-1:0] max_candidates;
    logic signed [DATA_WIDTH-1:0] thresh_logit;
    
    logic valid_in;
    logic [15:0] scale_id;
    logic [15:0] grid_x;
    logic [15:0] grid_y;
    logic [NUM_CLASSES*DATA_WIDTH-1:0] class_logits_in;
    logic [BINS*DATA_WIDTH-1:0] dist_l_in;
    logic [BINS*DATA_WIDTH-1:0] dist_t_in;
    logic [BINS*DATA_WIDTH-1:0] dist_r_in;
    logic [BINS*DATA_WIDTH-1:0] dist_b_in;
    
    // Outputs
    logic bram_wr_en;
    logic [ADDR_WIDTH-1:0] bram_wr_addr;
    logic [127:0] bram_wr_data;
    logic [ADDR_WIDTH-1:0] candidate_count;
    logic overflow_flag;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT Instantiation
    npu_detection_head #(
        .NUM_CLASSES(NUM_CLASSES),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_frame(clear_frame),
        .max_candidates(max_candidates),
        .thresh_logit(thresh_logit),
        .stream_valid(valid_in),
        .scale_id(scale_id),
        .grid_x(grid_x),
        .grid_y(grid_y),
        .stride(16'd1), // Default stride
        .class_logits(class_logits_in),
        .reg_l(dist_l_in),
        .reg_t(dist_t_in),
        .reg_r(dist_r_in),
        .reg_b(dist_b_in),
        .bram_wr_en(bram_wr_en),
        .bram_wr_addr(bram_wr_addr),
        .bram_wr_data(bram_wr_data),
        .candidate_count(candidate_count),
        .overflow_flag(overflow_flag)
    );

    // =========================================================================
    // Helper Tasks
    // =========================================================================
    task automatic set_class_score(input int class_idx, input logic signed [7:0] score);
        class_logits_in[class_idx*DATA_WIDTH +: DATA_WIDTH] = score;
    endtask

    task automatic set_dist_peak(
        ref logic [BINS*DATA_WIDTH-1:0] dist_array,
        input int peak_idx
    );
        for (int i = 0; i < BINS; i++) dist_array[i*DATA_WIDTH +: DATA_WIDTH] = -128;
        dist_array[peak_idx*DATA_WIDTH +: DATA_WIDTH] = 127;
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        $display("========================================");
        $display("Starting NPU Detection Head (Data Path) Tests");
        $display("========================================");
        
        // Reset
        rst_n = 0;
        clear_frame = 0;
        max_candidates = 50;
        thresh_logit = 8'd10;
        valid_in = 0;
        scale_id = 0; grid_x = 0; grid_y = 0;
        class_logits_in = '0;
        dist_l_in = '0; dist_t_in = '0; dist_r_in = '0; dist_b_in = '0;
        
        #20 rst_n = 1;
        
        // ---------------------------------------------------------------------
        // POV 10 - Integration (End-to-end Data Travel Path)
        // ---------------------------------------------------------------------
        @(posedge clk);
        // Inject Top-1 candidate (class 77, score 99)
        // Inject Top-2 candidate (class 12, score 55)
        for (int i = 0; i < NUM_CLASSES; i++) set_class_score(i, -128);
        set_class_score(77, 8'd99);
        set_class_score(12, 8'd55);
        
        // Setup spatial coordinates
        scale_id <= 16'h0001;
        grid_x <= 16'h0010; // 16
        grid_y <= 16'h0020; // 32
        
        // Setup distributions (l=5, t=10, r=4, b=8)
        set_dist_peak(dist_l_in, 5);
        set_dist_peak(dist_t_in, 10);
        set_dist_peak(dist_r_in, 4);
        set_dist_peak(dist_b_in, 8);
        
        valid_in <= 1;
        
        @(posedge clk);
        valid_in <= 0;
        
        // The data path latency:
        // TopK: 1 cycle
        // BBox Decoder: 1 cycle
        // Packer: 1 cycle to register the incoming data.
        fork
            begin : timeout
                #100;
                $error("POV 10: Data travel path timed out! No BRAM write observed.");
                $finish;
            end
            begin : monitor
                int writes_observed;
                writes_observed = 0;
                while (writes_observed < 1) begin
                    @(posedge clk);
                    if (bram_wr_en) begin
                        writes_observed++;
                        $display("Cycle %0t: BRAM Write Detected. Addr=%0d, Data=%h", $time, bram_wr_addr, bram_wr_data);
                        // Verify Top1 on first write
                        if (writes_observed == 1) begin
                            // Data format: [127:112] class_id, [111:96] score, [95:80] y2, [79:64] x2, [63:48] y1, [47:32] x1, [31:16] scale, [15:0] flags
                            if (bram_wr_data[127:112] !== 77) $error("POV 10: Top1 Class ID corrupted in transit.");
                            if (bram_wr_data[111:96]  !== 99) $error("POV 10: Top1 Score corrupted in transit.");
                            // grid_x=16. dist_l=5. x1 = 16-5 = 11.
                            if (bram_wr_data[47:32]   !== 11) $error("POV 10: Top1 X1 Box Coordinate corrupted. Expected 11, Got %d", bram_wr_data[47:32]);
                        end
                    end
                end
                disable timeout;
            end
        join
        
        $display("========================================");
        $display("Data Travel Path Tests Completed.");
        $display("========================================");
        $finish;
    end

endmodule
