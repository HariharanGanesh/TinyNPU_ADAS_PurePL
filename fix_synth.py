import os
import re

axi = "IP/TinyNPU200/src/axi4_lite_slave.v"
with open(axi, "r", encoding="utf-8") as f:
    code = f.read()
code = code.replace("reg [15:0] reg_frame_w;", "reg [31:0] reg_frame_w;")
code = code.replace("reg [15:0] reg_frame_h;", "reg [31:0] reg_frame_h;")
with open(axi, "w", encoding="utf-8") as f:
    f.write(code)

tb = "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
with open(tb, "r", encoding="utf-8") as f:
    code = f.read()

# Fix int match_count = 0 declaration location
# Find `integer fail_count = 0;` and put them there.
replacement = """integer fail_count = 0;
    int match_count = 0;
    int mismatch_count = 0;"""
code = code.replace("integer fail_count = 0;", replacement)
code = code.replace("int match_count = 0;", "")
code = code.replace("int mismatch_count = 0;", "")

with open(tb, "w", encoding="utf-8") as f:
    f.write(code)

print("Fixed")
