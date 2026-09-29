import re
text = open('IP/TinyNPU200/src/axis_sink.v').read()
text = text.replace('ST_FULL: begin', 'ST_FULL: begin\n                      $display("[AXIS_SINK @ %0t] ST_FULL! bytes_received=%0d", $time, bytes_received);')
open('IP/TinyNPU200/src/axis_sink.v', 'w').write(text)
