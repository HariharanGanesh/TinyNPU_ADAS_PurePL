import sys

filepath = "IP/TinyNPU200/src/tinynpu_top.v"
content = open(filepath, "r").read()

old_code = """    assign dw_weights_flat = {
        {(DATA_WIDTH*9*ARRAY_ROWS - DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS){1'b0}},
        weight_data_flat
    };"""

new_code = """    // Dynamically pad or truncate weight_data_flat to match the 9 weights per channel needed for DW
    generate
        if (ARRAY_COLS >= 9) begin
            // Extract the first 9 elements of each row. 
            // weight_data_flat is arranged as [row][col]. We need to unpack and repack.
            genvar r;
            for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_dw_weights
                assign dw_weights_flat[r*9*DATA_WIDTH +: 9*DATA_WIDTH] = 
                       weight_data_flat[r*ARRAY_COLS*DATA_WIDTH +: 9*DATA_WIDTH];
            end
        end else begin
            genvar r;
            for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_dw_weights_pad
                assign dw_weights_flat[r*9*DATA_WIDTH +: 9*DATA_WIDTH] = {
                    {(9 - ARRAY_COLS)*DATA_WIDTH{1'b0}},
                    weight_data_flat[r*ARRAY_COLS*DATA_WIDTH +: ARRAY_COLS*DATA_WIDTH]
                };
            end
        end
    endgenerate
"""

content = content.replace(old_code, new_code)
open(filepath, "w").write(content)
