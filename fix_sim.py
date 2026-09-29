tb = "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
with open(tb, "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace("    logic [31:0] read_val2;\n", "")
code = code.replace("logic [31:0] read_val;", "logic [31:0] read_val;\n    logic [31:0] read_val2;")

with open(tb, "w", encoding="utf-8") as f:
    f.write(code)
