`timescale 1ns/1ps

module tb_processing_element;
    // Parameters
    localparam DATA_WIDTH = 8;
    localparam ACCUM_WIDTH = 32;

    // Signals
    logic clk;
    logic reset_n;
    logic pe_en;
    logic psum_clear;
    logic weight_load;
    logic signed [DATA_WIDTH-1:0] weight_in;
    logic signed [DATA_WIDTH-1:0] act_in;
    logic act_valid_in;
    logic signed [ACCUM_WIDTH-1:0] psum_in;
    logic signed [ACCUM_WIDTH-1:0] psum_out;
    

    // DUT
    processing_element #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .pe_en(pe_en),
        .psum_clear(psum_clear),
        .weight_load(weight_load),
        .weight_in(weight_in),
        .act_in(act_in),
        .act_valid_in(act_valid_in),
        .psum_in(psum_in),
        .psum_out(psum_out));

    // Clock gen
    always #5 clk = ~clk;

    // Stats
    int tests_passed = 0;
    int tests_failed = 0;

    task check_output(input int expected_val, input string tc_name);
        if (psum_out === expected_val) begin
            $display("[PASS] %s: Expected %0d, Got %0d", tc_name, expected_val, psum_out);
            tests_passed++;
        end else begin
            $error("[FAIL] %s: Expected %0d, Got %0d", tc_name, expected_val, psum_out);
            tests_failed++;
        end
    endtask

    initial begin
        clk = 0;
        reset_n = 0;
        pe_en = 0;
        psum_clear = 0;
        weight_load = 0;
        weight_in = 0;
        act_in = 0;
        act_valid_in = 0;
        psum_in = 0;
        
        #20 reset_n = 1;
        #10 pe_en = 1;
        
        // TC01: 1 * 1 = 1
        @(posedge clk); #1;
        weight_load = 1; weight_in = 1;
        @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 1;
        @(posedge clk); #1; act_valid_in = 0;
        repeat(3) @(posedge clk); #1; check_output(1, "TC01 (1*1)");
        
        // TC02: 127 * 127 = 16129
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        weight_load = 1; weight_in = 127;
        @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 127;
        @(posedge clk); #1; act_valid_in = 0;
        repeat(3) @(posedge clk); #1; check_output(16129, "TC02 (127*127)");
        
        // TC03: -128 * 127 = -16256
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        weight_load = 1; weight_in = -128;
        @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 127;
        @(posedge clk); #1; act_valid_in = 0;
        repeat(3) @(posedge clk); #1; check_output(-16256, "TC03 (-128*127)");
        
        // TC04: -128 * -128 = 16384
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        weight_load = 1; weight_in = -128;
        @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = -128;
        @(posedge clk); #1; act_valid_in = 0;
        repeat(3) @(posedge clk); #1; check_output(16384, "TC04 (-128*-128)");
        
        // TC05: weight_load sequence
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        weight_load = 1; weight_in = 5;
        @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 10;
        @(posedge clk); #1; act_valid_in = 0;
        repeat(3) @(posedge clk); #1; check_output(50, "TC05 (weight reload)");

        // TC06: psum_clear
        @(posedge clk); #1;
        psum_clear = 1;
        @(posedge clk); #1;
        psum_clear = 0;
        #1; check_output(0, "TC06 (psum_clear)");
        @(posedge clk); #1;

        // TC07: Pipeline latency check (already implicitly 3 cycles in above tests)
        // explicitly checking
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        weight_load = 1; weight_in = 2; @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 3; @(posedge clk); #1;
        act_valid_in = 0;
        
        @(posedge clk); #1;
        
        @(posedge clk); #1;
        if(psum_out !== 6) begin $error("[FAIL] TC07 Latency late"); tests_failed++; end
        else begin $display("[PASS] TC07 (Latency)"); tests_passed++; end
        
        // TC08: pe_en = 0
        @(posedge clk); #1; psum_clear = 1; @(posedge clk); #1; psum_clear = 0;
        pe_en = 0;
        weight_load = 1; weight_in = 5; @(posedge clk); #1;
        weight_load = 0; act_valid_in = 1; act_in = 5; @(posedge clk); #1;
        act_valid_in = 0;
        repeat(3) @(posedge clk); #1;
        check_output(0, "TC08 (pe_en=0)");
        
        // Summary
        $display("==========================================");
        $display("REGRESSION SUMMARY: %0d/%0d tests passed", tests_passed, tests_passed + tests_failed);
        if (tests_failed == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL");
        $display("==========================================");
        
        $finish;
    end

    // SVA
    property latency_3;
        @(posedge clk) disable iff(!reset_n || !pe_en)
        (act_valid_in && !weight_load) |-> ##3 (psum_out !== 0);
    endproperty
    assert property(latency_3) else $error("Latency SVA failed!");
    
endmodule
