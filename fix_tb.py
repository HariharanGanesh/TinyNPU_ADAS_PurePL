import sys
content = open("rebuild_tb.py").read()
content = content.replace("else mismatch_count++;", "else begin mismatch_count++; $display(\"Got output: %h\", m_axis_tdata); end")
open("rebuild_tb.py", "w").write(content)
