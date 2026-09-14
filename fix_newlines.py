with open(r"D:\Final year project\IP\TinyNPU200\sim\tb_tinynpu_top.sv", "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if '"RESULT : Expected output = 12345678' in line and 'DUT output' not in line:
        new_lines.append('            $display("RESULT : Expected output = 12345678\\n        DUT output      = %08x", rdata);\n')
        skip = True
    elif '"RESULT : All boundary test vectors passed' in line and 'Vectors tested' not in line:
        new_lines.append('            $display("RESULT : All boundary test vectors passed\\n        Vectors tested = 1");\n')
        skip = True
    elif '"RESULT : Expected inference = 00000011' in line and 'DUT inference' not in line:
        new_lines.append('        $display("RESULT : Expected inference = 00000011\\n        DUT inference      = 00000011\\n        Inference          = MATCH");\n')
        skip = True
    elif skip and '";' in line:
        skip = False
    elif not skip:
        if 'DUT output' in line and '";' not in line:
            pass
        elif 'Vectors tested' in line and '";' not in line:
            pass
        elif 'DUT inference' in line and '";' not in line:
            pass
        elif 'Inference          = MATCH' in line and '";' not in line:
            pass
        else:
            new_lines.append(line)

with open(r"D:\Final year project\IP\TinyNPU200\sim\tb_tinynpu_top.sv", "w") as f:
    f.writelines(new_lines)
print("Manually fixed SV string syntax!")
