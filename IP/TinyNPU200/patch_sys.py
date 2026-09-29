import sys

with open('src/systolic_array.v', 'r') as f:
    code = f.read()

code = code.replace(
    'assign psum_valid_out_flat[c] = act_valid_w[ARRAY_ROWS-1][c+1];',
    'assign psum_valid_out_flat[c] = act_valid_w[ARRAY_ROWS-1][c+1];\nalways @(posedge clk) if (psum_valid_out_flat[c]) ("[SYSTOLIC @ %0t] Col %0d output valid psum=%h", , c, psum_out_flat[c*ACCUM_WIDTH*ARRAY_ROWS +: ACCUM_WIDTH*ARRAY_ROWS]);'
)

with open('src/systolic_array.v', 'w') as f:
    f.write(code)

print("Patch systolic_array.v complete")
