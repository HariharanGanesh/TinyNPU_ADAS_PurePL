import torch
import torch.nn as nn
import numpy as np
from tinyvelocity import TinyVelocity
import os

def fold_conv_bn(conv_weight, conv_bias, bn_rm, bn_rv, bn_eps, bn_w, bn_b):
    """ Folds BatchNorm into Conv2d """
    if conv_bias is None:
        conv_bias = torch.zeros(conv_weight.size(0))
    
    # Calculate scale: gamma / sqrt(running_var + eps)
    scale = bn_w / torch.sqrt(bn_rv + bn_eps)
    
    # Fold weight: W * scale
    folded_weight = conv_weight * scale.view(-1, 1, 1, 1)
    
    # Fold bias: (bias - running_mean) * scale + beta
    folded_bias = (conv_bias - bn_rm) * scale + bn_b
    
    return folded_weight, folded_bias

def quantize_symmetric(tensor, bits=8):
    """ Quantize float tensor to symmetric INT8 [-127, 127] """
    max_val = torch.max(torch.abs(tensor)).item()
    if max_val == 0:
        max_val = 1e-5
    
    scale = (2**(bits-1) - 1) / max_val
    quantized = torch.round(tensor * scale)
    quantized = torch.clamp(quantized, -(2**(bits-1)-1), 2**(bits-1)-1)
    
    return quantized.to(torch.int8), scale

def export_model_to_c_header(pth_path, output_header):
    print(f"Loading checkpoint: {pth_path}...")
    model = TinyVelocity(num_classes=1)
    model.load_state_dict(torch.load(pth_path, map_location='cpu'))
    model.eval()

    print(f"Exporting hardware weights to {output_header}...")
    
    with open(output_header, 'w') as f:
        f.write("#ifndef TINYVELOCITY_WEIGHTS_H\n")
        f.write("#define TINYVELOCITY_WEIGHTS_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write("// INT8 Quantized Hardware Weights for TinyNPU300\n")
        f.write("// Extracted from tinyvelocity_cars_best.pth\n\n")

        total_weight_bytes = 0
        layer_idx = 0
        
        # Iterate through modules and fold BN -> Quantize
        for name, module in model.named_modules():
            if isinstance(module, nn.Conv2d):
                # Try to find a subsequent BatchNorm2d
                # This is a naive heuristic for Sequential blocks, but works for TinyVelocity's structure
                parent_name = name.rsplit('.', 1)[0]
                parent = dict(model.named_modules())[parent_name]
                
                bn_module = None
                if isinstance(parent, nn.Sequential):
                    # Find next layer in Sequential
                    conv_idx = int(name.rsplit('.', 1)[1])
                    if str(conv_idx + 1) in parent._modules:
                        next_mod = parent._modules[str(conv_idx + 1)]
                        if isinstance(next_mod, nn.BatchNorm2d):
                            bn_module = next_mod
                elif 'dw' in name:
                    # DWConv block structure: self.dw followed by self.bn1
                    bn_module = parent.bn1
                elif 'pw' in name:
                    # DWConv block structure: self.pw followed by self.bn2
                    bn_module = parent.bn2

                # Get raw weights
                w = module.weight.detach()
                b = module.bias.detach() if module.bias is not None else None

                if bn_module is not None:
                    print(f"Folding BN into {name}")
                    w, b = fold_conv_bn(w, b, 
                                        bn_module.running_mean, 
                                        bn_module.running_var, 
                                        bn_module.eps, 
                                        bn_module.weight, 
                                        bn_module.bias)
                else:
                    print(f"No BN found for {name}, using direct weights")
                    if b is None:
                        b = torch.zeros(w.size(0))

                # Quantize Weights to INT8
                w_q, w_scale = quantize_symmetric(w, bits=8)
                
                # Quantize Bias to INT32 (using scaled float directly for simple PTQ)
                # In true hardware, bias is quantized via (input_scale * weight_scale)
                # We will approximate this by scaling bias to fit INT32 limits
                b_q, b_scale = quantize_symmetric(b, bits=32)

                # Flatten arrays
                w_flat = w_q.flatten().numpy()
                b_flat = b_q.flatten().numpy()
                total_weight_bytes += len(w_flat)

                # Write to Header
                safe_name = name.replace('.', '_')
                
                # Write Weights
                f.write(f"// Layer {layer_idx}: {name} | Shape: {w.shape} | Scale: {w_scale:.4f}\n")
                f.write(f"const int8_t weights_{safe_name}[{len(w_flat)}] __attribute__((aligned(32))) = {{\n")
                f.write("    " + ", ".join(map(str, w_flat)) + "\n")
                f.write("};\n\n")

                # Write Bias
                f.write(f"const int32_t bias_{safe_name}[{len(b_flat)}] __attribute__((aligned(32))) = {{\n")
                f.write("    " + ", ".join(map(str, b_flat)) + "\n")
                f.write("};\n\n")

                layer_idx += 1

        f.write(f"// Total Memory Footprint: {total_weight_bytes} Bytes ({total_weight_bytes/1024:.2f} KB)\n\n")
        f.write("#endif // TINYVELOCITY_WEIGHTS_H\n")
        
        print(f"Successfully generated header! Total model size: {total_weight_bytes/1024:.2f} KB.")

if __name__ == "__main__":
    pth = "tinyvelocity_cars_best.pth"
    out = "../tinyvelocity_weights.h"
    export_model_to_c_header(pth, out)
