import os

files = [
    "IP/TinyNPU200/src/axi4_lite_slave.v",
    "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
]

for file in files:
    with open(file, "rb") as f:
        data = f.read()
    if data.startswith(b'\xef\xbb\xbf'):
        with open(file, "wb") as f:
            f.write(data[3:])
            
print("BOM stripped")
