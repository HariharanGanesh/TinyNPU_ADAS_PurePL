import re
text = open('IP/TinyNPU200/src/axis_source.v').read()
text = text.replace('if (start_drain && !buf_empty) begin', 'if (start_drain) $display("[AXIS_SRC @ %0t] start_drain=1 buf_empty=%b", $time, buf_empty);\n                      if (start_drain && !buf_empty) begin')
open('IP/TinyNPU200/src/axis_source.v', 'w').write(text)
