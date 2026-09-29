import os
import re

src_dir = "IP/TinyNPU200/src"
files = [f for f in os.listdir(src_dir) if f.endswith('.v') or f.endswith('.sv')]

modules = {}

for f in files:
    path = os.path.join(src_dir, f)
    with open(path, 'r', encoding='utf-8') as file:
        content = file.read()
        
        # Find module definitions
        mod_match = re.search(r'module\s+(\w+)', content)
        if mod_match:
            mod_name = mod_match.group(1)
            
            # Find instantiations (rudimentary)
            insts = re.findall(r'^\s*([a-zA-Z_]\w*)\s+(?:#\([\s\S]*?\))?\s*([a-zA-Z_]\w*)\s*\(', content, re.MULTILINE)
            # Filter out standard verilog keywords
            keywords = ['if', 'case', 'always', 'always_ff', 'always_comb', 'assign', 'wire', 'reg', 'logic', 'endmodule', 'begin', 'end']
            insts = [i for i in insts if i[0] not in keywords]
            
            modules[mod_name] = {
                'file': f,
                'instantiates': [i[0] for i in insts]
            }

print("=== Module Dependencies ===")
for m, data in modules.items():
    print(f"{m} ({data['file']})")
    for inst in data['instantiates']:
        print(f"  -> {inst}")
        
# Check DMA controller activation load
dma_path = os.path.join(src_dir, "dma_controller.v")
if os.path.exists(dma_path):
    with open(dma_path, 'r', encoding='utf-8') as dma_file:
        dma_code = dma_file.read()
        print("\n=== DMA Controller 'act_load' check ===")
        for line in dma_code.split('\n'):
            if 'act' in line.lower() and 'load' in line.lower():
                print(line.strip())

# Check top level for DMA activation inputs
top_path = os.path.join(src_dir, "tinynpu_top.v")
if os.path.exists(top_path):
    with open(top_path, 'r', encoding='utf-8') as top_file:
        top_code = top_file.read()
        print("\n=== Top Level DMA Instantiation ===")
        # extract u_dma instantiation
        dma_inst = re.search(r'dma_controller.*?u_dma[\s\S]*?\);', top_code)
        if dma_inst:
            print(dma_inst.group(0))

# Check axi4lite_slave for simultaneous AW/W
axi_path = os.path.join(src_dir, "axi4lite_slave.v")
if os.path.exists(axi_path):
    with open(axi_path, 'r', encoding='utf-8') as axi_file:
        axi_code = axi_file.read()
        print("\n=== AXI-Lite Slave AW/W Handshake check ===")
        # Look for awready and wready logic
        awready_logic = re.search(r'always @.*awready.*?(?=end).*?end', axi_code, re.DOTALL | re.IGNORECASE)
        wready_logic = re.search(r'always @.*wready.*?(?=end).*?end', axi_code, re.DOTALL | re.IGNORECASE)
        if awready_logic: print("awready logic found.")
        if wready_logic: print("wready logic found.")
        # just print lines containing awready and wready updates
        for line in axi_code.split('\n'):
            if 'awready <=' in line or 'wready <=' in line or 'awvalid' in line and 'wvalid' in line:
                print(line.strip())

