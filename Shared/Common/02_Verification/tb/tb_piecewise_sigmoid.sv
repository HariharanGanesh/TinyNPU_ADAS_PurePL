`timescale 1ns/1ps
module tb_piecewise_sigmoid;
    logic [7:0] x_in;
    logic [7:0] sigmoid_out;
    
    piecewise_sigmoid u_dut (
        .x_in(x_in),
        .sigmoid_out(sigmoid_out)
    );

    int fails = 0;
    
    // Golden reference function (implemented identically to Python model)
    function logic [7:0] expected_sigmoid(logic [7:0] x);
        if (x <= 64) return 0;
        else if (x <= 96) return ((x - 64) * 15) >> 4;
        else if (x <= 128) return 30 + (x - 96) * 3;
        else if (x <= 160) return 128 + (x - 128) * 3;
        else if (x <= 192) return 225 + (((x - 160) * 15) >> 4);
        else return 255;
    endfunction

    initial begin
        $display("Testing piecewise_sigmoid...");
        for (int i = 0; i < 256; i++) begin
            x_in = i;
            #1; // wait for comb logic
            if (sigmoid_out !== expected_sigmoid(x_in)) begin
                $error("FAIL at x=%0d: out=%0d expected=%0d", x_in, sigmoid_out, expected_sigmoid(x_in));
                fails++;
            end
        end
        if (fails == 0)
            $display("PASS: All 256 inputs matched expected values.");
        else
            $display("FAIL: %0d mismatches.", fails);
        $finish;
    end
endmodule
