import os

def generate_dummy_data_header(filename, num_weights=4096, num_acts=4096):
    with open(filename, 'w') as f:
        f.write("#ifndef DUMMY_DATA_H\n")
        f.write("#define DUMMY_DATA_H\n\n")
        f.write("#include <stdint.h>\n\n")
        
        f.write(f"// Dummy 1-valued Weights for FPGA Data Flow Verification\n")
        f.write(f"// Size: {num_weights} bytes\n")
        f.write(f"const int8_t dummy_weights[{num_weights}] __attribute__((aligned(32))) = {{\n")
        
        for i in range(num_weights):
            f.write("    1,")
            if (i + 1) % 16 == 0:
                f.write("\n")
                
        f.write("};\n\n")
        
        f.write(f"// Dummy 1-valued Activations for FPGA Data Flow Verification\n")
        f.write(f"// Size: {num_acts} bytes\n")
        f.write(f"const int8_t dummy_activations[{num_acts}] __attribute__((aligned(32))) = {{\n")
        
        for i in range(num_acts):
            f.write("    1,")
            if (i + 1) % 16 == 0:
                f.write("\n")
                
        f.write("};\n\n")
        
        # Add an M0 and Shift parameter array for requantization (set to Identity)
        f.write(f"// Dummy Requantization Parameters (M0=1, Shift=0 for Identity)\n")
        f.write(f"const int32_t dummy_m0[32] __attribute__((aligned(32))) = {{")
        f.write("1, "*32)
        f.write("};\n")
        f.write(f"const int32_t dummy_shift[32] __attribute__((aligned(32))) = {{")
        f.write("0, "*32)
        f.write("};\n")
        f.write(f"const int32_t dummy_bias[32] __attribute__((aligned(32))) = {{")
        f.write("0, "*32)
        f.write("};\n\n")
        
        f.write("#endif // DUMMY_DATA_H\n")
        
if __name__ == "__main__":
    generate_dummy_data_header("d:\\Final year project\\dummy_data.h")
    print("Generated dummy_data.h successfully!")
