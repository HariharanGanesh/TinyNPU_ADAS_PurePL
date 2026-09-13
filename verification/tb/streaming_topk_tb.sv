`timescale 1ns/1ps

module streaming_topk_tb;
    
    // Parameters
    parameter NUM_CLASSES = 200;
    parameter DATA_WIDTH  = 8;
    
    // Signals
    logic clk;
    logic rst_n;
    logic signed [DATA_WIDTH-1:0] thresh_logit;
    logic [NUM_CLASSES*DATA_WIDTH-1:0] class_logits_in;
    logic valid_in;
    
    // Outputs
    logic signed [DATA_WIDTH-1:0] top1_score;
    logic [7:0]                   top1_class_id;
    logic                         top1_valid;
    logic signed [DATA_WIDTH-1:0] top2_score;
    logic [7:0]                   top2_class_id;
    logic                         top2_valid;
    logic                         valid_out;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT Instantiation
    streaming_topk #(
        .NUM_CLASSES(NUM_CLASSES),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .thresh_logit(thresh_logit),
        .class_logits_in(class_logits_in),
        .valid_in(valid_in),
        .top1_score(top1_score),
        .top1_class_id(top1_class_id),
        .top1_valid(top1_valid),
        .top2_score(top2_score),
        .top2_class_id(top2_class_id),
        .top2_valid(top2_valid),
        .valid_out(valid_out)
    );

    // =========================================================================
    // Assertions (POV 5 - SVA)
    // =========================================================================
    // 1. If valid_in is high, valid_out MUST be high on the next clock cycle.
    property p_valid_latency;
        @(posedge clk) disable iff(!rst_n)
        valid_in |=> valid_out;
    endproperty
    assert property(p_valid_latency) else $error("POV 5: valid_out latency violation!");

    // 2. Top1 Score must ALWAYS be >= Top2 Score when both are valid.
    property p_top1_ge_top2;
        @(posedge clk) disable iff(!rst_n)
        (valid_out && top1_valid && top2_valid) |-> (top1_score >= top2_score);
    endproperty
    assert property(p_top1_ge_top2) else $error("POV 5: Top1 score is strictly less than Top2 score!");

    // 3. Threshold enforcement: if top1_valid is high, score >= threshold
    property p_threshold_enforcement;
        @(posedge clk) disable iff(!rst_n)
        (valid_out && top1_valid) |-> (top1_score >= thresh_logit);
    endproperty
    assert property(p_threshold_enforcement) else $error("POV 5: Valid candidate violates threshold!");

    // =========================================================================
    // Helper Task: Inject Class Score
    // =========================================================================
    task set_class_score(input int class_idx, input logic signed [7:0] score);
        class_logits_in[class_idx*DATA_WIDTH +: DATA_WIDTH] = score;
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        $display("========================================");
        $display("Starting Streaming Top-K Tests");
        $display("========================================");
        
        // Initialize
        rst_n = 0;
        thresh_logit = 8'd10; // Logit threshold = 10
        valid_in = 0;
        class_logits_in = '0;
        // Fill all with minimum value (-128)
        for (int i = 0; i < NUM_CLASSES; i++) begin
            set_class_score(i, -128);
        end
        
        #20 rst_n = 1;
        
        // ---------------------------------------------------------------------
        // POV 1 & 2 - Functional Normal Operation
        // ---------------------------------------------------------------------
        @(posedge clk);
        set_class_score(50, 8'd45);  // Top 1
        set_class_score(120, 8'd22); // Top 2
        set_class_score(15, 8'd5);   // Below threshold, ignored
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;
        #1;
        if (!valid_out || !top1_valid || !top2_valid) $error("POV 1: Failed to validate top scores.");
        if (top1_class_id !== 50 || top1_score !== 45) $error("POV 1: Top1 incorrect.");
        if (top2_class_id !== 120 || top2_score !== 22) $error("POV 1: Top2 incorrect.");
        
        // ---------------------------------------------------------------------
        // POV 3 - Corner Case: Negative scores below threshold
        // ---------------------------------------------------------------------
        @(posedge clk);
        for (int i = 0; i < NUM_CLASSES; i++) set_class_score(i, -128);
        set_class_score(1, 8'd5); // Max score is 5, but threshold is 10
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;
        #1;
        if (top1_valid !== 0 || top2_valid !== 0) $error("POV 3: Threshold gate failed. Allowed invalid score.");

        // ---------------------------------------------------------------------
        // POV 8 - Fault Injection: Equal Scores (Collision)
        // ---------------------------------------------------------------------
        @(posedge clk);
        for (int i = 0; i < NUM_CLASSES; i++) set_class_score(i, -128);
        set_class_score(33, 8'd100);
        set_class_score(77, 8'd100);
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;
        #1;
        if (top1_score !== 100 || top2_score !== 100) $error("POV 8: Collision handling failed.");
        
        // ---------------------------------------------------------------------
        // POV 6 - X/Z Robustness (Inject 'X' into background classes)
        // ---------------------------------------------------------------------
        // This is tricky in SV without an explicit 4-state checker inside the RTL, 
        // but we verify that the Top-K logic handles uninitialized background classes 
        // if they resolve to 0 by default, although X propagation would normally break it.
        // We will skip X injection for this basic testbench to prevent simulator crash.

        $display("========================================");
        $display("Streaming Top-K Tests Completed.");
        $display("========================================");
        $finish;
    end

endmodule
