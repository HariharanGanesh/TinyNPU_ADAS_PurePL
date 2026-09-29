import sys

with open('src/tinynpu_top.v', 'r') as f:
    code = f.read()

# Replace threshold filter connection
code = code.replace(
    '.wr_data(thresh_out_flat),\n        .wr_en(out_buf_wr_en & thresh_out_valid),',
    '.wr_data(csr_layer_type == 0 ? pool_out_flat : thresh_out_flat),\n        .wr_en(out_buf_wr_en & (csr_layer_type == 0 ? pool_out_valid : thresh_out_valid)),'
)

with open('src/tinynpu_top.v', 'w') as f:
    f.write(code)

print("Patch tinynpu_top.v complete")
