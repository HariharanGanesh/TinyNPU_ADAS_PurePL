#!/usr/bin/env python3
import struct

def to_int8(val):
    if val > 127: return 127
    if val < -128: return -128
    return int(val)

def generate_adversarial_case(out_dir, prefix, rows=8, cols=8, is_zero=False):
    # Generates a 64-byte frame (8x8) and exactly 64 weights/biases
    
    # 1. Hostile configuration
    csr_start = 1
    M0 = 0x7FFFFFFF # Max multiplier
    shift = 30 # Large shift
    mode = 0 # ReLU
    
    with open(f"{out_dir}/{prefix}_cfg.txt", "w") as f:
        f.write(f"M0={M0:08x}\nshift={shift}\nmode={mode}\n")

    # 2. Hostile Weights and Biases
    wgt = []
    # bias per column
    for c in range(cols):
        bias = 1000000 if not is_zero else 0
        wgt.append(bias & 0xFFFFFFFF)
        for r in range(rows):
            w = -128 if not is_zero else 0
            wgt.append(w & 0xFF)

    with open(f"{out_dir}/{prefix}_wgt_mem.txt", "w") as f:
        for val in wgt:
            f.write(f"{val:08x}\n")
            
    with open(f"{out_dir}/{prefix}_wgt_mem.hex", "w") as f:
        for val in wgt:
            f.write(f"{val:08x}\n")

    # 3. Hostile Activations
    acts = []
    for _ in range(64):
        a = 127 if not is_zero else 0
        acts.append(a & 0xFF)

    # Sensor data (1 byte per line)
    with open(f"{out_dir}/{prefix}_act_stream.hex", "w") as f:
        for a in acts:
            f.write(f"{a:02x}\n")

    # 4. Independent Mathematical Model (Reference B)
    expected_out = []
    for c in range(cols):
        acc = 1000000 if not is_zero else 0
        for r in range(rows):
            w = -128 if not is_zero else 0
            x = 127 if not is_zero else 0
            acc += w * x
        
        # Test exact rounding
        scaled = acc * M0
        rnd = (1 << (shift - 1)) if shift > 0 else 0
        shifted = (scaled + rnd) >> shift
        
        # Activation
        out = to_int8(shifted)
        if mode == 0 and out < 0:
            out = 0
            
        expected_out.append(out & 0xFF)
        
    with open(f"{out_dir}/{prefix}_expected_out.hex", "w") as f:
        for _ in range(8): # 8 outputs per row
            for e in expected_out:
                f.write(f"{e:02x}\n")

if __name__ == '__main__':
    generate_adversarial_case(".", "redteam_adv", is_zero=False)
    generate_adversarial_case(".", "redteam_zero", is_zero=True)
    print("Red-Team vectors generated.")
