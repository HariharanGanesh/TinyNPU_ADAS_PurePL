import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np

np.random.seed(42)

# Consume the same random calls as generate_top_test_vectors.py does first
in_act_first = np.random.randint(-15, 15, (8, 8, 1), dtype=np.int8)
weights_row0 = np.random.randint(-8, 8, (8,), dtype=np.int8)

# Now the same seed state as when the script generates the actual test vectors
in_act_vec = np.random.randint(-20, 20, (8,), dtype=np.int8)
weights_mat = np.random.randint(-10, 10, (8, 8), dtype=np.int8)

print('act_vec:', list(in_act_vec))
print('weights_mat:')
print(weights_mat)

bias_val = -5
M0 = int(round(0.5 * (2**31)))
n_shift = 31

print('M0:', M0, 'n_shift:', n_shift)

psums = [0]*8
for col in range(8):
    for row in range(8):
        psums[col] += int(in_act_vec[row]) * int(weights_mat[row, col])

print('psums:', psums)

expected_out = []
for col in range(8):
    biased = psums[col] + bias_val
    product = biased * M0
    if n_shift > 0:
        product += (1 << (n_shift - 1))
    result = product >> n_shift
    result = max(-128, min(127, result))
    # ReLU
    result = max(0, result)
    expected_out.append(result)

print('expected_out:', expected_out)
print('expected_out hex:', [hex(x & 0xFF) for x in expected_out])

# Write the hex files
out_dir = os.path.join(os.path.dirname(__file__), '../verif/tb')
os.makedirs(out_dir, exist_ok=True)

with open(os.path.join(out_dir, 'tc1_act_stream.txt'), 'w') as f:
    for v in in_act_vec:
        f.write(f'{int(v) & 0xFF:02x}\n')

with open(os.path.join(out_dir, 'tc1_wgt_mem.txt'), 'w') as f:
    for row in range(8):
        for col in range(8):
            f.write(f'{int(weights_mat[row, col]) & 0xFF:02x}\n')

with open(os.path.join(out_dir, 'tc1_expected_out.txt'), 'w') as f:
    for v in expected_out:
        f.write(f'{int(v) & 0xFF:02x}\n')

with open(os.path.join(out_dir, 'tc1_cfg.txt'), 'w') as f:
    f.write(f'M0={M0}\n')
    f.write(f'n_shift={n_shift}\n')
    f.write(f'bias={bias_val}\n')

print('[SUCCESS] Test vectors written to', out_dir)
