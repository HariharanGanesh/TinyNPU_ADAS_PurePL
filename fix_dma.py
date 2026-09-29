import sys
content = open("IP/TinyNPU200/src/dma_controller.v").read()
content = content.replace("STATE_IDLE: begin if (start_load_wgt) $display(\"DMA_CTRL: wgt_size=%0d\", dma_transfer_size);", "STATE_IDLE: begin")
open("IP/TinyNPU200/src/dma_controller.v", "w").write(content)
