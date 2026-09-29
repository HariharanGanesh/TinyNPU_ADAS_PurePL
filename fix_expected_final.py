import sys
content = open("rebuild_tb.py").read()
content = content.replace("expected_output = 32'h1C; // 28", "expected_output = 32'h1C1C1C1C;")
open("rebuild_tb.py", "w").write(content)
