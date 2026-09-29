import os
import re

src_dir = "IP/TinyNPU200/src"

with open("audit_out.txt", "w", encoding="utf-8") as out:
    # Check top level for DMA activation inputs
    top_path = os.path.join(src_dir, "tinynpu_top.v")
    if os.path.exists(top_path):
        with open(top_path, 'r', encoding='utf-8') as top_file:
            top_code = top_file.read()
            out.write("\n=== Top Level DMA Instantiation ===\n")
            dma_inst = re.search(r'dma_controller.*?u_dma[\s\S]*?\);', top_code)
            if dma_inst:
                out.write(dma_inst.group(0) + "\n")

    # Check axi4lite_slave for simultaneous AW/W
    axi_path = os.path.join(src_dir, "axi4_lite_slave.v") # Note the name is axi4_lite_slave.v
    if os.path.exists(axi_path):
        with open(axi_path, 'r', encoding='utf-8') as axi_file:
            axi_code = axi_file.read()
            out.write("\n=== AXI-Lite Slave AW/W Handshake check ===\n")
            for line in axi_code.split('\n'):
                if 'awready <=' in line or 'wready <=' in line or ('awvalid' in line and 'wvalid' in line) or 'awready' in line and 'wready' in line:
                    out.write(line.strip() + "\n")
                    
    # Check CSR unused
    out.write("\n=== CSR Audit ===\n")
    if os.path.exists(top_path):
        with open(top_path, 'r', encoding='utf-8') as top_file:
            top_code = top_file.read()
            # find all wire [31:0] csr_
            csrs = re.findall(r'wire\s+\[31:0\]\s+(csr_\w+)', top_code)
            for csr in csrs:
                # count usages in top_code
                usages = top_code.count(csr)
                out.write(f"{csr}: {usages} occurrences\n")
