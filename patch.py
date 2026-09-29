import re
text = open('IP/TinyNPU200/src/npu_controller.v').read()
text = text.replace('STATE_LOAD_ACT: begin', 'STATE_LOAD_ACT: begin\n                    $display("[NPU_CTRL @ %0t] In STATE_LOAD_ACT, stream_act_load_done=%b", $time, stream_act_load_done);')
open('IP/TinyNPU200/src/npu_controller.v', 'w').write(text)
