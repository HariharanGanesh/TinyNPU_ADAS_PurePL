import shutil

src_file = r'D:\Final year project\IP\TinyNPU200\src\tinynpu_top.v'
dst_file = r'D:\Final year project\IP\NPU300PM\src\tinynpu_top.v'
ipshared_file = r'D:\Final year project\RISCV_ADAS_PURE_PL\RISCV_ADAS_PURE_PL.gen\sources_1\bd\npu_system\ipshared\aeb6\9987\tinynpu_top.v'

with open(src_file, 'r', encoding='utf-8') as f:
    text = f.read()

# Fix 1: Add TILE_SIZE parameter to axis_source
text = text.replace(') u_axis_source (', '    .TILE_SIZE(TILE_SIZE)\n    ) u_axis_source (')

# Fix 2: Remove drain_words pipelined calculation and port
start_idx = text.find('// Pipelined drain_words calculation')
if start_idx != -1:
    end_idx = text.find('axis_source #(', start_idx)
    if end_idx != -1:
        text = text[:start_idx] + text[end_idx:]
text = text.replace('.drain_words(total_drain_words),', '')

# Fix 3: DMA and Stream logic
text = text.replace('.dma_start_store_out(dma_start_store_out),', '.dma_start_load_act(dma_start_load_act),\n        .dma_start_store_out(dma_start_store_out),')
text = text.replace('.stream_act_load_done(stream_tile_received),', '.dma_act_load_done(stream_tile_received),')

# Fix 4: Requant M0 and n_shift flat
text = text.replace('.M0_flat({ARRAY_ROWS{csr_m0[SCALE_WIDTH-1:0]}}),', '.M0_flat({ARRAY_ROWS{csr_m0}}),')
text = text.replace('.n_shift_flat({ARRAY_ROWS{csr_n_shift[SHIFT_WIDTH-1:0]}}),', '.n_shift_flat({ARRAY_ROWS{csr_n_shift}}),')

with open(dst_file, 'w', encoding='utf-8') as f:
    f.write(text)
with open(ipshared_file, 'w', encoding='utf-8') as f:
    f.write(text)

print('Success')
