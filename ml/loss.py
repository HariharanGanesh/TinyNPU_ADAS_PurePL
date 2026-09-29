import torch
import torch.nn as nn
import torch.nn.functional as F

def neg_loss(pred, gt):
    """
    Focal Loss for Heatmap Center Detection.
    Modified from CornerNet / CenterNet.
    pred: (batch, channels, H, W) -> Network predictions (Sigmoid applied)
    gt: (batch, channels, H, W) -> Ground truth Gaussian heatmaps
    """
    # Clip predictions to prevent log(0)
    pred = torch.clamp(pred, min=1e-4, max=1 - 1e-4)

    # Find the exact center pixels (where gt is 1)
    pos_inds = gt.eq(1).float()
    
    # Find all other pixels (where gt < 1)
    neg_inds = gt.lt(1).float()

    # Calculate focal weights
    # For positive pixels: weight by how wrong the network was (1 - pred)^alpha
    # For negative pixels: weight by how wrong it was, AND reduce penalty if it's close to a center (1 - gt)^beta
    pos_weights = torch.pow(1 - pred, 2)
    neg_weights = torch.pow(1 - gt, 4) * torch.pow(pred, 2)

    # Binary Cross Entropy with focal weights
    pos_loss = torch.log(pred) * pos_weights * pos_inds
    neg_loss = torch.log(1 - pred) * neg_weights * neg_inds

    num_pos  = pos_inds.float().sum()
    
    pos_loss = pos_loss.sum()
    neg_loss = neg_loss.sum()

    if num_pos == 0:
        loss = -neg_loss
    else:
        loss = -(pos_loss + neg_loss) / num_pos
        
    return loss

class TinyVelocityLoss(nn.Module):
    def __init__(self):
        super().__init__()
        
    def forward(self, pred_hm, gt_hm):
        return neg_loss(pred_hm, gt_hm)
