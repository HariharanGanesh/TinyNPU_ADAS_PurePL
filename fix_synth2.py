tb = "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
with open(tb, "r", encoding="utf-8") as f:
    code = f.read()

# Let's just fix it properly using regex
import re
code = re.sub(r'int\s+match_count\s*=\s*0;\s*int\s+mismatch_count\s*=\s*0;', '', code)
if "int match_count" not in code:
    code = code.replace("integer fail_count = 0;", "integer fail_count = 0;\n    int match_count = 0;\n    int mismatch_count = 0;")

with open(tb, "w", encoding="utf-8") as f:
    f.write(code)
