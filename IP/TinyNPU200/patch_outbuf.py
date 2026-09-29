import sys

with open('src/output_buffer.v', 'r') as f:
    code = f.read()

code = code.replace(
    '        if (wr_en && !full) begin',
    '        if (wr_en && !full) begin\n            ("[OUT_BUF @ %0t] Writing data=%h", , wr_data);'
)
code = code.replace(
    '        if (rd_en && !empty) begin',
    '        if (rd_en && !empty) begin\n            ("[OUT_BUF @ %0t] Reading data=%h", , rd_data);'
)

with open('src/output_buffer.v', 'w') as f:
    f.write(code)

print("Patch output_buffer.v complete")
