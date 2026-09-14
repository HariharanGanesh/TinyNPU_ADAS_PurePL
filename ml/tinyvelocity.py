import torch
import torch.nn as nn

class DWConv(nn.Module):
    def __init__(self, in_channels, out_channels, stride=1):
        super().__init__()
        # Depthwise
        self.dw = nn.Conv2d(in_channels, in_channels, kernel_size=3, stride=stride, padding=1, groups=in_channels, bias=False)
        self.bn1 = nn.BatchNorm2d(in_channels)
        self.act1 = nn.ReLU6(inplace=True)
        # Pointwise
        self.pw = nn.Conv2d(in_channels, out_channels, kernel_size=1, stride=1, padding=0, bias=False)
        self.bn2 = nn.BatchNorm2d(out_channels)
        self.act2 = nn.ReLU6(inplace=True)

    def forward(self, x):
        x = self.act1(self.bn1(self.dw(x)))
        x = self.act2(self.bn2(self.pw(x)))
        return x

class TinyVelocity(nn.Module):
    def __init__(self, num_classes=1):
        super().__init__()
        # Motion Front-End assumes input is pre-processed (e.g., Frame[t] - Frame[t-1])
        # Input: 256x256x1 (grayscale motion diff) or 3 (RGB diff). Let's assume 1 for extreme speed.
        self.stem = nn.Sequential(
            nn.Conv2d(1, 16, kernel_size=3, stride=2, padding=1, bias=False), # 256 -> 128
            nn.BatchNorm2d(16),
            nn.ReLU6(inplace=True)
        )
        
        # Backbone: Hardware-Aligned Channels for 8x8 INT8 Systolic Array
        self.stage1 = DWConv(16, 16, stride=1)      # 128x128x16
        self.stage2 = DWConv(16, 32, stride=2)      # 64x64x32
        self.stage3 = DWConv(32, 48, stride=2)      # 32x32x48
        self.stage4 = DWConv(48, 64, stride=2)      # 16x16x64
        
        # Detection Head (Single-scale Heatmap, NO ANCHORS)
        self.head_conv = nn.Sequential(
            nn.Conv2d(64, 64, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm2d(64),
            nn.ReLU6(inplace=True)
        )
        
        # Heatmap Center Prediction (e.g. 1 channel for 'car')
        self.heatmap = nn.Sequential(
            nn.Conv2d(64, num_classes, kernel_size=1, bias=True),
            nn.Sigmoid()
        )
        
        # Optional: Sub-pixel offset (dx, dy) for higher precision
        self.offset = nn.Conv2d(64, 2, kernel_size=1, bias=True)
        
        # Optional: Object Size (w, h)
        self.size = nn.Conv2d(64, 2, kernel_size=1, bias=True)

    def forward(self, x):
        x = self.stem(x)
        x = self.stage1(x)
        x = self.stage2(x)
        x = self.stage3(x)
        x = self.stage4(x)
        
        feat = self.head_conv(x)
        
        hm = self.heatmap(feat)
        off = self.offset(feat)
        wh = self.size(feat)
        
        return hm, off, wh

if __name__ == '__main__':
    # Initialize the model for 1 class (e.g., 'car')
    model = TinyVelocity(num_classes=1)
    
    # Calculate parameter count
    total_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f'TinyVelocity initialized for 1 class (car).')
    print(f'Total Trainable Parameters: {total_params:,}')
    
    # Dummy forward pass
    dummy_input = torch.randn(1, 1, 256, 256)
    hm, off, wh = model(dummy_input)
    print(f'Input shape: {dummy_input.shape}')
    print(f'Heatmap shape: {hm.shape} (Expected: 1, 1, 16, 16)')
    print(f'Offset shape: {off.shape} (Expected: 1, 2, 16, 16)')
    print(f'Size shape: {wh.shape} (Expected: 1, 2, 16, 16)')
