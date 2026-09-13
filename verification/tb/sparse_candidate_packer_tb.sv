`timescale 1ns/1ps

module sparse_candidate_packer_tb;
    
    // Parameters
    parameter ADDR_WIDTH = 10;
    
    // Signals
    logic clk;
    logic rst_n;
    logic [ADDR_WIDTH-1:0] max_candidates;
    logic clear_frame;
    logic valid_in;
    logic [15:0] class_id, score, bbox_x1, bbox_y1, bbox_x2, bbox_y2, scale_id, flags;
    
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
    sparse_candidate_packer #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .max_candidates(max_candidates),
        .clear_frame(clear_frame),
        .valid_in(valid_in),
        .class_id(class_id),
        .score(score),
        .bbox_x1(bbox_x1),
        .bbox_y1(bbox_y1),
        .bbox_x2(bbox_x2),
        .bbox_y2(bbox_y2),
        .scale_id(scale_id),
        .flags(flags),
        .bram_wr_en(bram_wr_en),
        .bram_wr_addr(bram_wr_addr),
        .bram_wr_data(bram_wr_data),
        .candidate_count(candidate_count),
        .overflow_flag(overflow_flag)
    );

    // Assertions (POV 5 - SVA)
    property p_no_write_on_overflow;
        @(posedge clk) disable iff(!rst_n)
        (overflow_flag |=> !bram_wr_en);
    endproperty
    assert property (p_no_write_on_overflow) else $error("BRAM write enabled during overflow!");

    property p_count_never_exceeds_max;
        @(posedge clk) disable iff(!rst_n)
        (candidate_count <= max_candidates);
    endproperty
    assert property (p_count_never_exceeds_max) else $error("Candidate count exceeded max_candidates!");

    // Test Sequence
    initial begin
        $display("========================================");
        $display("Starting Sparse Candidate Packer Tests");
        $display("========================================");
        
        // POV 4 - Reset Test
        rst_n = 0;
        clear_frame = 0;
        valid_in = 0;
        max_candidates = 10; // Small max for overflow testing
        class_id = 0; score = 0; bbox_x1 = 0; bbox_y1 = 0; bbox_x2 = 0; bbox_y2 = 0; scale_id = 0; flags = 0;
        
        #20 rst_n = 1;
        
        if (candidate_count !== 0 || overflow_flag !== 0) 
            $error("POV 4 (Reset): Failed to clear outputs.");
        
        // POV 1 & 2 - Functional & Interface (Normal Write)
        @(posedge clk);
        valid_in <= 1;
        class_id <= 16'hAAAA; score <= 16'h5555;
        @(posedge clk);
        valid_in <= 0;
        #1;
        if (!bram_wr_en || bram_wr_addr !== 0 || candidate_count !== 1)
            $error("POV 1 (Functional): Write enable or count failed on normal write.");
            
        // POV 3 & 8 - Corner Cases & Overflow Fault Injection
        @(posedge clk);
        max_candidates <= 3; 
        // We already wrote 1. Write 3 more to force overflow.
        valid_in <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        valid_in <= 0;
        
        @(posedge clk);
        #1;
        if (candidate_count !== 3 || overflow_flag !== 1)
            $error("POV 3/8 (Corner/Fault): Overflow flag did not trigger correctly, or count exceeded limit. count=%d, overflow=%b", candidate_count, overflow_flag);
            
        // POV 1 - Clear Frame
        @(posedge clk);
        clear_frame <= 1;
        @(posedge clk);
        clear_frame <= 0;
        @(posedge clk);
        #1;
        if (candidate_count !== 0 || overflow_flag !== 0)
            $error("POV 1 (Functional): clear_frame did not reset counters.");
            
        $display("========================================");
        $display("Tests Completed.");
        $display("========================================");
        $finish;
    end
endmodule
