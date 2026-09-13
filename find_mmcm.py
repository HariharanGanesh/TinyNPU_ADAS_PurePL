import sys

target = 74.25
input_freq = 1000.0 / 7.0

best_err = 1000000
best_m = 0
best_d = 0
best_dclk = 0

for dclk in range(1, 10):
    for m_int in range(5 * 8, 64 * 8 + 1):
        m = m_int / 8.0
        vco = input_freq * m / dclk
        if vco < 600 or vco > 1200:
            continue
        
        for dout_int in range(1 * 8, 128 * 8 + 1):
            dout = dout_int / 8.0
            out_freq = vco / dout
            err = abs(out_freq - target)
            if err < best_err:
                best_err = err
                best_m = m
                best_d = dout
                best_dclk = dclk

print(f"Best: M={best_m}, D={best_d}, DCLK={best_dclk}, err={best_err} MHz")
print(f"Output: {input_freq * best_m / best_dclk / best_d} MHz")
