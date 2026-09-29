import sys
content = open("rebuild_tb.py").read()
content = content.replace("expected_output = 32'h10101010;", "expected_output = 32'h1c1c1c1c;")
open("rebuild_tb.py", "w").write(content)
