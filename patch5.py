import re
text = open('IP/TinyNPU200/src/axis_source.v').read()
text = text.replace('ST_SEND: begin', 'ST_SEND: begin\n                      $display("[AXIS_SRC @ %0t] ST_SEND! valid=%b ready=%b buf_rd_data=%h latch_word=%h", $time, m_axis_tvalid, m_axis_tready, buf_rd_data, latch_word);')
open('IP/TinyNPU200/src/axis_source.v', 'w').write(text)
