import sys
content = open("rebuild_tb.py").read()
content = content.replace("s_axis_tdata = 32'h00000002;", "s_axis_tdata = 32'h02020202;")
open("rebuild_tb.py", "w").write(content)
