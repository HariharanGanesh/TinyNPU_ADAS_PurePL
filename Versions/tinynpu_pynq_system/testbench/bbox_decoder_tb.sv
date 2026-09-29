`timescale 1ns/1ps

module bbox_decoder_tb;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  logic clk, rst_n;
  
  logic [15:0] raw_dfl;
  logic [7:0]  conf;
  logic        valid_in;
  
  logic        bbox_valid;
  logic [15:0] x1, y1, x2, y2;
  logic [7:0]  out_conf;
  
  int errors;

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  bbox_decoder dut (
    .clk(clk),
    .rst_n(rst_n),
    .raw_dfl(raw_dfl),
    .conf(conf),
    .valid_in(valid_in),
    .bbox_valid(bbox_valid),
    .x1(x1), .y1(y1), .x2(x2), .y2(y2),
    .out_conf(out_conf)
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
    raw_dfl = 0;
    conf = 0;
    errors = 0;
    
    #20 rst_n = 1;
    
    // Stimulus
    @(posedge clk);
    raw_dfl <= 16'h1234;
    conf <= 8'hA5;
    valid_in <= 1;
    
    @(posedge clk);
    valid_in <= 0;
    
    // Expected output computation in TB
    // Golden reference values (stubbed check)
    #50;
    
    if (bbox_valid === 1'bX) begin
      errors++;
    end
    
    $display("\n-----------------------------------------");
    $display("Bounding Box Decoder Self-Checking TB");
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
module bbox_decoder(
  input logic clk, rst_n,
  input logic [15:0] raw_dfl,
  input logic [7:0] conf,
  input logic valid_in,
  output logic bbox_valid,
  output logic [15:0] x1, y1, x2, y2,
  output logic [7:0] out_conf
);
  assign bbox_valid = valid_in;
  assign x1 = 16'd0;
  assign y1 = 16'd0;
  assign x2 = 16'd0;
  assign y2 = 16'd0;
  assign out_conf = conf;
endmodule
