import sys

with open('src/threshold_filter.v', 'r') as f:
    code = f.read()

code = code.replace(
    '        if (valid_in_reg && pass_reg) begin',
    '        if (valid_in_reg && pass_reg) begin\n                ("[THRESH @ %0t] Output valid data=%h", , data_in_reg);'
)
code = code.replace(
    '        end else begin\n            if (valid_in_reg && pass_reg) begin',
    '        end else begin\n            if (valid_in_reg) ("[THRESH @ %0t] Received valid_in=%b pass=%b", , valid_in_reg, pass_reg);\n            if (valid_in_reg && pass_reg) begin'
)

with open('src/threshold_filter.v', 'w') as f:
    f.write(code)

print("Patch threshold_filter.v complete")
