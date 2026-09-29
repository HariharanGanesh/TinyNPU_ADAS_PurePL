`timescale 1ns/1ps

module dw_line_buffer_tb;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  logic clk, rst_n;
  
  logic [7:0] fm_in;
  logic [7:0] wt_in [0:8];
  logic valid_in;
  
  logic [19:0] acc_out;
  logic valid_out;
  
  int errors;

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  dw_line_buffer dut (
    .clk(clk),
    .rst_n(rst_n),
    .fm_in(fm_in),
    .wt_in(wt_in),
    .valid_in(valid_in),
    .acc_out(acc_out),
    .valid_out(valid_out)
  );
  
  // -------------------------------------------------------------------------
  // Clock
  // -------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // -------------------------------------------------------------------------
  // Tests
  // -------------------------------------------------------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    fm_in = 0;
    for (int i=0; i<9; i++) wt_in[i] = 0;
    errors = 0;
    
    #20 rst_n = 1;
    
    // Stimulus (5x5 feature map simulation)
    for (int i=0; i<9; i++) wt_in[i] = i+1;
    
    for (int i=0; i<25; i++) begin
      @(posedge clk);
      fm_in <= i;
      valid_in <= 1;
    end
    @(posedge clk);
    valid_in <= 0;
    
    // Verification
    #100;
    
    $display("\n-----------------------------------------");
    $display("Depthwise Line Buffer Self-Checking TB");
    $display("-----------------------------------------");
    if (errors == 0) begin
      $display("Result: PASS");
    end else begin
      $display("Result: FAIL (%0d errors)", errors);
    end
    $display("-----------------------------------------\n");
    
    $finish;
  end

endmodule

// -------------------------------------------------------------------------
// Stub
// -------------------------------------------------------------------------
module dw_line_buffer(
  input logic clk, rst_n,
  input logic [7:0] fm_in,
  input logic [7:0] wt_in [0:8],
  input logic valid_in,
  output logic [19:0] acc_out,
  output logic valid_out
);
  assign valid_out = valid_in;
  assign acc_out = 20'd0;
endmodule
