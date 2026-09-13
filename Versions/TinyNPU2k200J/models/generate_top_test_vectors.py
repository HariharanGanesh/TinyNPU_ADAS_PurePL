# =============================================================================
# Python script: generate_top_test_vectors.py
# Project: TinyNPU
# Description:
#   Generates input/output stimulus files and expected results for the
#   top-level SystemVerilog testbench (tinynpu_top_tb.sv).
#   Uses the Python golden reference model to ensure cycle/value accuracy.
# =============================================================================

import os
import numpy as np
from golden_model import (
    requantize_int32_to_int8,
    conv2d_int8,
    depthwise_conv2d_int8
)

def save_hex_file(data, filepath, width_bits=8):
    """Save array as hex text file for Verilog $readmemh."""
    with open(filepath, 'w') as f:
        for val in data.flatten():
            # Handle negative numbers for hex format (two's complement)
            mask = (1 << width_bits) - 1
            val_masked = int(val) & mask
            hex_str = f"{val_masked:0{width_bits//4}x}"
            f.write(hex_str + "\n")
    print(f"[INFO] Saved test vector: {filepath}")

def main():
    # Make sure we save in the verif/tb directory
    out_dir = os.path.join(os.path.dirname(__file__), "../verif/tb")
    os.makedirs(out_dir, exist_ok=True)

    np.random.seed(42)

    # =========================================================================
    # Test Case 1: Standard Conv / MatMul (8x8 tile, 1 channel in, 8 channels out)
    # =========================================================================
    print("\n--- Generating Test Case 1 (Standard Conv) ---")
    
    # 8x8 input patch, 1 channel
    in_act = np.random.randint(-15, 15, (8, 8, 1), dtype=np.int8)
    
    # 1x1 weights for 1 in_channel, 8 out_channels -> 1x1x1x8 -> total 8 weights
    # But systolic array expects 8x8 weights (8 rows, 8 cols)
    # Let's map it: rows = input channels (8), cols = output channels (8)
    # We will pad the weight array to 8x8
    weights_standard = np.zeros((8, 8), dtype=np.int8)
    # Set first row to random weights, others 0
    weights_standard[0, :] = np.random.randint(-8, 8, (8,), dtype=np.int8)

    # Bias, scale, shift
    bias_val = -5
    M0 = int(round(0.5 * (2**31))) # scale of 0.5 -> M0 = 1073741824
    n_shift = 31

    # Golden compute:
    # out[col] = (in_act[row] * weight[row][col] + bias) * M0 >> n_shift
    # Since in_act has shape (8, 8), the controller streams them row by row.
    # In standard mode, the systolic array computes 8 parallel channels.
    # Let's compute expected results for the 8 parallel outputs
    expected_acc = np.zeros(8, dtype=np.int32)
    # For standard conv in TinyNPU top-level, it streams the 64 activations
    # and accumulates. Let's model the exact accumulation:
    for r in range(8):
        for c in range(8):
            # Streamed activation at step = r*8 + c
            act = in_act[r, c, 0]
            # Accumulate on each of the 8 columns
            # Column c gets weight from row 0 when we stream channel 0
            # Wait, standard FSM setup: streams 64 activations
            # Let's check how many steps are computed:
            # npu_controller: total_compute_steps = csr_in_channels * csr_kernel_size * csr_kernel_size = 1 * 1 * 1 = 1 step?
            # Wait! FSM compute step count is in_channels (1) * K^2 (1) = 1 step.
            # But the activations loaded into buffer is H*W = 8*8 = 64 bytes.
            # Let's assume standard matmul/conv where we compute a full tile.
            pass

    # Let's write a simplified direct test scenario that matches npu_controller:
    # FSM: total_compute_steps = csr_in_channels (1) * K (1) * K (1) = 1 cycle.
    # Wait, if total_compute_steps = 1, it only computes for 1 cycle!
    # Let's set the FSM registers in our test bench:
    # csr_in_channels = 8
    # csr_kernel_size = 1
    # csr_stride = 1
    # csr_input_width = 1
    # csr_input_height = 1
    # This means spatial dimension is 1x1, with 8 input channels!
    # This matches exactly an 8-input-channel matrix vector multiplication!
    # So activations streamed = 8 (one vector of 8 channels).
    # This is perfect! Let's generate this exact test vector:
    
    in_act_vec = np.random.randint(-20, 20, (8,), dtype=np.int8)  # 8 input channels
    weights_mat = np.random.randint(-10, 10, (8, 8), dtype=np.int8) # 8x8 matrix (rows=in, cols=out)
    
    # Golden dot product: psum[col] = sum_{row} act[row] * weight[row][col]
    psums = np.zeros(8, dtype=np.int32)
    for col in range(8):
        for row in range(8):
            psums[col] += np.int32(in_act_vec[row]) * np.int32(weights_mat[row, col])

    # Requantize
    expected_out = np.zeros(8, dtype=np.int8)
    for col in range(8):
        expected_out[col] = requantize_int32_to_int8(
            np.array([psums[col]], dtype=np.int32),
            M0=M0,
            n=n_shift,
            bias_int32=bias_val
        )[0]
        # ReLU activation
        expected_out[col] = max(np.int8(0), expected_out[col])

    print(f"  Inputs: {in_act_vec}")
    print(f"  Weights:\n{weights_mat}")
    print(f"  Psums: {psums}")
    print(f"  Expected Outputs: {expected_out}")

    # Save to files
    # Activations are mapped to activation_buffer. The DMA or stream interface
    # fills the 8 parallel channel buffers. In our AXI-Stream interface,
    # the axis_sink writes them.
    # The axis_sink expects pixels one by one.
    # Let's write them as 8 bytes representing the input vector.
    save_hex_file(in_act_vec, os.path.join(out_dir, "tc1_act_stream.txt"), width_bits=8)
    
    # Weight buffer expects weights in memory order.
    # The weight buffer is loaded via DMA. The size is ARRAY_ROWS * ARRAY_COLS = 64 bytes.
    # Weight memory order in weight_buffer.v is:
    # word 0: weight[0][0], word 1: weight[0][1], ..., word 63: weight[7][7]
    # So we flatten weights_mat row by row.
    save_hex_file(weights_mat, os.path.join(out_dir, "tc1_wgt_mem.txt"), width_bits=8)
    
    # Expected output is 8 bytes
    save_hex_file(expected_out, os.path.join(out_dir, "tc1_expected_out.txt"), width_bits=8)

    # Save scale/shift/bias parameters as a python snippet or config file
    with open(os.path.join(out_dir, "tc1_cfg.txt"), "w") as f:
        f.write(f"M0={M0}\n")
        f.write(f"n_shift={n_shift}\n")
        f.write(f"bias={bias_val}\n")

    print("[SUCCESS] Test Case 1 vectors generated.")

if __name__ == "__main__":
    main()
