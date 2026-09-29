import sys

with open('src/requantization_unit.v', 'r') as f:
    code = f.read()

code = code.replace(
    '        if (!rst_n) begin',
    '        if (acc_valid) ("[REQUANT @ %0t] acc_valid=1", );\n        if (!rst_n) begin'
)

with open('src/requantization_unit.v', 'w') as f:
    f.write(code)

print("Patch requantization_unit.v complete")
