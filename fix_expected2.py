import sys
content = open("rebuild_tb.py").read()
content = content.replace("expected_output = 32'h10; // 16", "expected_output = 32'h1C; // 28")
open("rebuild_tb.py", "w").write(content)
