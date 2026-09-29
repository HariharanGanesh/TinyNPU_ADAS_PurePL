import re
text = open('IP/TinyNPU200/src/dma_controller.v').read()
text = text.replace('wgt_wr_data <= m_axi_rdata[AXI_DATA_WIDTH-1:0];', 'wgt_wr_data <= m_axi_rdata[7:0];\n                          if (wgt_wr_addr == 0) $display("[DMA] writing %h to wgt_addr 0 (rdata=%h)", m_axi_rdata[7:0], m_axi_rdata);')
open('IP/TinyNPU200/src/dma_controller.v', 'w').write(text)
