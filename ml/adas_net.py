import torch
import torch.nn as nn
from torch.ao.quantization import QuantStub, DeQuantStub

# =============================================================================
# HARDWARE-ALIGNED NEURAL NETWORK BLOCKS
# Designed specifically for the 20x8 INT8 Systolic Array (TinyNPU)
# =============================================================================

class HardwareAlignedBlock(nn.Module):
    """
    MobileNetV2-style Depthwise Separable Convolution Block.
    Optimized for the NPU's 20-PE Vector Unit and 160-MAC Systolic Array.
    """
    def __init__(self, in_channels, out_channels, stride=1):
        super(HardwareAlignedBlock, self).__init__()
        
        # 1. Depthwise Convolution (Mapped to the 20-PE Parallel Vector Unit)
        # Groups = in_channels for extreme efficiency
        self.dw_conv = nn.Conv2d(in_channels, in_channels, kernel_size=3, stride=stride, 
                                 padding=1, groups=in_channels, bias=False)
        self.bn1 = nn.BatchNorm2d(in_channels)
        self.act1 = nn.Hardswish(inplace=True) # Supported natively by the 256-entry hardware ROM
        
        # 2. Pointwise Convolution 1x1 (Mapped to the 20x8 Systolic Array)
        self.pw_conv = nn.Conv2d(in_channels, out_channels, kernel_size=1, stride=1, 
                                 padding=0, bias=False)
        self.bn2 = nn.BatchNorm2d(out_channels)
        self.act2 = nn.Hardswish(inplace=True)

    def forward(self, x):
        x = self.dw_conv(x)
        x = self.bn1(x)
        x = self.act1(x)
        
        x = self.pw_conv(x)
        x = self.bn2(x)
        x = self.act2(x)
        return x

# =============================================================================
# MAIN ADAS NPU ARCHITECTURE
# =============================================================================

class ADAS_NPU_Model(nn.Module):
    def __init__(self, num_classes):
        super(ADAS_NPU_Model, self).__init__()
        
        # Quantization Stubs (Required for PTQ / QAT to export INT8 hardware weights)
        self.quant = QuantStub()
        self.dequant = DeQuantStub()
        
        # ---------------------------------------------------------------------
        # BACKBONE (Channels strictly locked to multiples of 20 and 8)
        # ---------------------------------------------------------------------
        # Stem: 3 RGB Channels -> 20 Channels (100% Systolic Row Utilization)
        self.stem = nn.Sequential(
            nn.Conv2d(3, 20, kernel_size=3, stride=2, padding=1, bias=False),
            nn.BatchNorm2d(20),
            nn.Hardswish(inplace=True)
        )
        
        # Stage 1: 20 -> 40 Channels (Stride 2 for spatial reduction)
        self.stage1 = HardwareAlignedBlock(20, 40, stride=2)
        
        # Stage 2: 40 -> 80 Channels (Stride 2)
        self.stage2 = HardwareAlignedBlock(40, 80, stride=2)
        
        # Stage 3: 80 -> 160 Channels (Stride 2)
        self.stage3 = HardwareAlignedBlock(80, 160, stride=2)
        
        # ---------------------------------------------------------------------
        # YOLO-STYLE GRID DETECTION HEAD
        # ---------------------------------------------------------------------
        # No anchors, pure spatial grid decoding for absolute maximum FPS
        
        # Head Feature Extraction (160 -> 40 to save BRAM)
        self.head_conv = nn.Sequential(
            nn.Conv2d(160, 40, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm2d(40),
            nn.Hardswish(inplace=True)
        )
        
        # Output 1: Heatmap (Objectness + Classification)
        # Channels = Number of Classes
        self.heatmap = nn.Sequential(
            nn.Conv2d(40, num_classes, kernel_size=1, bias=True),
            nn.Sigmoid() # Computed in software (RISC-V) at the very end
        )
        
        # Output 2: Bounding Box Center Offset (dx, dy)
        self.offset = nn.Conv2d(40, 2, kernel_size=1, bias=True)
        
        # Output 3: Bounding Box Size (Width, Height)
        self.size = nn.Conv2d(40, 2, kernel_size=1, bias=True)

    def forward(self, x):
        # 1. Quantize Input to INT8
        x = self.quant(x)
        
        # 2. Extract Features
        x = self.stem(x)
        x = self.stage1(x)
        x = self.stage2(x)
        x = self.stage3(x)
        
        # 3. Detection Head
        feat = self.head_conv(x)
        
        # 4. Dequantize outputs back to Float for the Loss Function (or RISC-V post-processing)
        feat_float = self.dequant(feat)
        
        hm = self.heatmap(feat_float)
        off = self.offset(feat_float)
        wh = self.size(feat_float)
        
        return hm, off, wh

# =============================================================================
# MODEL INSTANTIATIONS & VERIFICATION
# =============================================================================

if __name__ == '__main__':
    print("=====================================================")
    print("       ADAS TINYNPU DEEP LEARNING ARCHITECTURE       ")
    print("=====================================================\n")
    
    # 1. The LITE Model (Cars & Pedestrians)
    # Extremely fast, low BRAM footprint, handles primary collisions.
    model_lite = ADAS_NPU_Model(num_classes=2)
    lite_params = sum(p.numel() for p in model_lite.parameters() if p.requires_grad)
    print(f"[Model Lite] Classes: 2 (Cars, Pedestrians)")
    print(f"[Model Lite] Total Parameters: {lite_params:,} (~{lite_params/1024:.1f} KB INT8 Weights)\n")
    
    # 2. The FULL Model (Cars, Pedestrians, Traffic Lights, Lane Lines)
    # Comprehensive ADAS perception engine.
    model_full = ADAS_NPU_Model(num_classes=4)
    full_params = sum(p.numel() for p in model_full.parameters() if p.requires_grad)
    print(f"[Model Full] Classes: 4 (Cars, Pedestrians, Traffic Lights, Lane Lines)")
    print(f"[Model Full] Total Parameters: {full_params:,} (~{full_params/1024:.1f} KB INT8 Weights)\n")
    
    # -------------------------------------------------------------------------
    # Hardware Tensor Geometry Verification
    # -------------------------------------------------------------------------
    print("--- Dummy Hardware Data Flow Test ---")
    dummy_video_frame = torch.randn(1, 3, 256, 256)
    hm, off, wh = model_lite(dummy_video_frame)
    
    print(f"Input Video Resolution: {dummy_video_frame.shape[2]}x{dummy_video_frame.shape[3]}")
    print(f"Output Spatial Grid:    {hm.shape[2]}x{hm.shape[3]}")
    print("Output Tensors:")
    print(f"  - Heatmap Shape: {hm.shape} (Matches {hm.shape[1]} classes)")
    print(f"  - Offset Shape:  {off.shape} (X, Y shifts)")
    print(f"  - Size Shape:    {wh.shape} (Width, Height)\n")
    
    if lite_params < 65536:
        print("[SUCCESS] The Model Lite easily fits within the FPGA's 64KB Weight BRAM Limit!")
    else:
        print("[WARNING] The model exceeds the physical PL BRAM constraint. Weights must be streamed via DMA.")
        
    print("Ready for PyTorch training!")
