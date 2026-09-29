import sys

filepath = "IP/TinyNPU200/src/tinynpu_top.v"
content = open(filepath, "r").read()
content = content.replace("parameter ARRAY_COLS      = 8,", "parameter ARRAY_COLS      = 14,")
open(filepath, "w").write(content)
