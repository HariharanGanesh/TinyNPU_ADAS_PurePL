import re

# Remove debug print from npu_controller
text = open('IP/TinyNPU200/src/npu_controller.v').read()
lines = text.split('\n')
lines = [l for l in lines if 'In STATE_LOAD_ACT, dma_act_load_done' not in l]
open('IP/TinyNPU200/src/npu_controller.v', 'w').write('\n'.join(lines))

# Remove debug print from weight_buffer
text = open('IP/TinyNPU200/src/weight_buffer.v').read()
lines = text.split('\n')
lines = [l for l in lines if 'WGT_BUF] wrote' not in l]
open('IP/TinyNPU200/src/weight_buffer.v', 'w').write('\n'.join(lines))

# Remove debug print from dma_controller
text = open('IP/TinyNPU200/src/dma_controller.v').read()
text = text.replace('wgt_wr_data <= m_axi_rdata[7:0];\n                          if (wgt_wr_addr == 0) $display', 'wgt_wr_data <= m_axi_rdata[7:0];\n                          //if (wgt_wr_addr == 0) $display')
open('IP/TinyNPU200/src/dma_controller.v', 'w').write(text)

# Remove debug prints from axis_source
text = open('IP/TinyNPU200/src/axis_source.v').read()
lines = text.split('\n')
lines = [l for l in lines if 'AXIS_SRC' not in l]
open('IP/TinyNPU200/src/axis_source.v', 'w').write('\n'.join(lines))

# Remove debug prints from axis_sink
text = open('IP/TinyNPU200/src/axis_sink.v').read()
lines = text.split('\n')
lines = [l for l in lines if 'AXIS_SINK' not in l]
open('IP/TinyNPU200/src/axis_sink.v', 'w').write('\n'.join(lines))

# Remove debug prints from requantization_unit
text = open('IP/TinyNPU200/src/requantization_unit.v').read()
lines = text.split('\n')
lines = [l for l in lines if 'REQUANT' not in l]
open('IP/TinyNPU200/src/requantization_unit.v', 'w').write('\n'.join(lines))

print('All debug prints removed successfully')
