#!/usr/bin/env python3
"""
npu_golden_model.py - TinyNPU Independent Python Golden Reference Model
Author: Autonomous DV Engineer
"""
import struct, math

def to_int8(x):
    x = int(x)
    if x > 127: return 127
    if x < -128: return -128
    return x

def to_int32(x):
    x = int(x) & 0xFFFFFFFF
    if x >= 0x80000000: x -= 0x100000000
    return x

def sign_extend(val, bits):
    if val & (1 << (bits - 1)): val -= (1 << bits)
    return val

# PE MAC
def pe_mac(weight_u8, act_u8, psum_i32):
    w = sign_extend(weight_u8 & 0xFF, 8)
    a = sign_extend(act_u8 & 0xFF, 8)
    return to_int32(psum_i32 + w * a)

# Requantization
def requantize(acc_i32, M0_u32, n_shift, bias_i32):
    biased = int(acc_i32) + int(bias_i32)
    scaled = biased * int(M0_u32 & 0xFFFFFFFF)
    round_const = (1 << (n_shift - 1)) if n_shift > 0 else 0
    if n_shift == 0:
        shifted = scaled
    else:
        shifted = (scaled + round_const) >> n_shift
    return to_int8(shifted)

# Activation functions
def relu(x): return max(0, to_int8(x))
def relu6(x): return min(max(to_int8(x), 0), 6)
def identity(x): return to_int8(x)
def activation(x, mode):
    if mode == 0:   return relu(x)
    elif mode == 1: return identity(x)
    elif mode == 2: return relu6(x)
    return identity(x)

# Piecewise sigmoid - CORRECT (16-bit widened)
def piecewise_sigmoid_ref(x):
    x = x & 0xFF
    if x <= 64:   return 0
    elif x <= 96: return min(255, ((x - 64) * 15) >> 4)
    elif x <= 128: return min(255, 30 + (x - 96) * 3)
    elif x <= 160: return min(255, 128 + (x - 128) * 3)
    elif x <= 192: return min(255, 225 + (((x - 160) * 15) >> 4))
    else: return 255

# Piecewise sigmoid - BUGGY RTL (8-bit truncation)
def piecewise_sigmoid_rtl(x):
    x = x & 0xFF
    if x <= 64:   return 0
    elif x <= 96: return (((x - 64) & 0xFF) * 15 & 0xFF) >> 4
    elif x <= 128: return min(255, (30 + (x - 96) * 3) & 0xFF)
    elif x <= 160: return min(255, (128 + (x - 128) * 3) & 0xFF)
    elif x <= 192: return min(255, (225 + ((((x-160) & 0xFF)*15 & 0xFF) >> 4)) & 0xFF)
    else: return 255

# BBox decode
def bbox_decode(dist_l, dist_t, dist_r, dist_b, grid_x, grid_y, stride, fw, fh):
    sh = stride >> 1
    cx = grid_x * stride + sh
    cy = grid_y * stride + sh
    px_l = (dist_l & 0xFF) * stride
    px_t = (dist_t & 0xFF) * stride
    px_r = (dist_r & 0xFF) * stride
    px_b = (dist_b & 0xFF) * stride
    x1 = max(0, cx - px_l)
    y1 = max(0, cy - px_t)
    x2 = min(fw, cx + px_r)
    y2 = min(fh, cy + px_b)
    return x1, y1, x2, y2

# 2x2 MaxPool (signed)
def maxpool2x2_pixel(v00, v01, v10, v11):
    vals = [sign_extend(v & 0xFF, 8) for v in [v00, v01, v10, v11]]
    return max(vals)

if __name__ == '__main__':
    # BUG-004: Enumerate piecewise sigmoid mismatches
    mismatches = []
    for x in range(256):
        ref = piecewise_sigmoid_ref(x)
        rtl = piecewise_sigmoid_rtl(x)
        if ref != rtl:
            mismatches.append((x, ref, rtl))
    print(f'[BUG-004] piecewise_sigmoid mismatches: {len(mismatches)}/256')
    for x, r, b in mismatches[:5]:
        print(f'  x={x} correct={r} rtl_buggy={b}')

    # PE corner cases
    tests = [(127,127,0), (-128,-128,0), (127,-128,0), (0,0,100)]
    print('\n[PE MAC] Corner cases:')
    for w,a,p in tests:
        res = pe_mac(w & 0xFF, a & 0xFF, to_int32(p))
        print(f'  w={w} a={a} psum_in={p} -> psum_out={res}')

    # Requant sanity
    print('\n[Requant] Saturation test:')
    print(f'  acc=100000 M0=1 shift=0 bias=0 -> {requantize(100000, 1, 0, 0)} (expect 127)')
    print(f'  acc=-100000 M0=1 shift=0 bias=0 -> {requantize(-100000, 1, 0, 0)} (expect -128)')

    print('\n[BBox] Sanity check:')
    print(f'  {bbox_decode(2,2,2,2,5,5,32,160,160)}')
    print('  (expect (112,112,160,160))')

    print('\nGolden model OK.')
