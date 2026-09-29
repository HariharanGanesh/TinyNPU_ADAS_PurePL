import sys
content = open("rebuild_tb.py").read()
content = content.replace("axi_write_independent(8'h20, 32'h11223344, 0, 5);", "axi_write_independent(8'h2C, 32'h11223344, 0, 5);")
open("rebuild_tb.py", "w").write(content)
