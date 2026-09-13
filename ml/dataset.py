import torch
import math
from torch.utils.data import Dataset
import numpy as np

def draw_umich_gaussian(heatmap, center, radius, k=1):
    """
    Draws a 2D Gaussian at the given center on the heatmap.
    This creates the "Glowing Orb" effect instead of a single hard pixel.
    """
    diameter = 2 * radius + 1
    gaussian = gaussian2D((diameter, diameter), sigma=diameter / 6)
    
    x, y = int(center[0]), int(center[1])
    height, width = heatmap.shape[0:2]
    
    left, right = min(x, radius), min(width - x, radius + 1)
    top, bottom = min(y, radius), min(height - y, radius + 1)
    
    masked_heatmap  = heatmap[y - top:y + bottom, x - left:x + right]
    masked_gaussian = gaussian[radius - top:radius + bottom, radius - left:radius + right]
    
    if min(masked_gaussian.shape) > 0 and min(masked_heatmap.shape) > 0: # TODO debug
        np.maximum(masked_heatmap, masked_gaussian * k, out=masked_heatmap)
    return heatmap

def gaussian2D(shape, sigma=1):
    m, n = [(ss - 1.) / 2. for ss in shape]
    y, x = np.ogrid[-m:m+1,-n:n+1]
    h = np.exp(-(x * x + y * y) / (2 * sigma * sigma))
    h[h < np.finfo(h.dtype).eps * h.max()] = 0
    return h

class DummyCarDataset(Dataset):
    """
    A mock dataset to test the training loop.
    It generates random noise images, but places a fake "car" (a brighter patch)
    at a random location. The ground truth heatmap is generated at that exact location.
    """
    def __init__(self, size=1000):
        self.size = size

    def __len__(self):
        return self.size

    def __getitem__(self, idx):
        # Generate random 256x256 image (1 channel for speed)
        img = np.random.rand(3, 256, 256).astype(np.float32)
        
        # Pick a random center for the fake "car"
        # We limit to [20, 236] to avoid the edges
        car_x = np.random.randint(20, 236)
        car_y = np.random.randint(20, 236)
        
        # Draw the "car" on the image (just make a small 10x10 square slightly brighter)
        img[:, car_y-5:car_y+5, car_x-5:car_x+5] += 0.5
        # Normalize back to 0-1
        img = np.clip(img, 0.0, 1.0)
        
        # Ground Truth Heatmap is 16x16 (Downsampled by 16)
        hm = np.zeros((1, 16, 16), dtype=np.float32)
        
        # Calculate center in heatmap coordinates (divide by 16)
        hm_x = car_x // 16
        hm_y = car_y // 16
        
        # Draw the Gaussian splat!
        hm[0] = draw_umich_gaussian(hm[0], (hm_x, hm_y), radius=2)
        
        return torch.from_numpy(img), torch.from_numpy(hm)
