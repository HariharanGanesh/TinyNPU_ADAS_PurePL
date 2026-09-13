import torch
from torch.utils.data import DataLoader
from adas_net import ADAS_NPU_Model
from dataset import DummyCarDataset
from loss import TinyVelocityLoss
import time

def train():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"==========================================")
    print(f" Starting ADAS_NPU_Model Training Pipeline")
    print(f" Hardware: {device}")
    print(f"==========================================")

    # 1. Initialize Model (1 class for the Dummy Dataset)
    model = ADAS_NPU_Model(num_classes=1).to(device)
    
    # 2. Setup Dataset
    train_dataset = DummyCarDataset(size=5000)
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=0)
    
    # 3. Setup Loss and Optimizer
    criterion = TinyVelocityLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    
    epochs = 5
    best_loss = float('inf')

    # 4. Training Loop
    print("\nStarting Training Loop...")
    for epoch in range(epochs):
        model.train()
        epoch_loss = 0.0
        start_time = time.time()
        
        for batch_idx, (images, gt_heatmaps) in enumerate(train_loader):
            images = images.to(device)
            gt_heatmaps = gt_heatmaps.to(device)
            
            optimizer.zero_grad()
            
            # Forward Pass: Predict heatmap, offset, wh
            pred_hm, pred_off, pred_wh = model(images)
            
            # Loss (Our dummy dataset only provides heatmap ground truth for now)
            loss = criterion(pred_hm, gt_heatmaps)
            
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            
            if batch_idx % 20 == 0:
                print(f"Epoch [{epoch+1}/{epochs}] Batch [{batch_idx}/{len(train_loader)}] Loss: {loss.item():.4f}")
                
        avg_loss = epoch_loss / len(train_loader)
        epoch_time = time.time() - start_time
        print(f"\n--- Epoch {epoch+1} Complete | Avg Loss: {avg_loss:.4f} | Time: {epoch_time:.2f}s ---")
        
        if avg_loss < best_loss:
            best_loss = avg_loss
            torch.save(model.state_dict(), "adas_net_best.pth")
            print(">>> Saved new best model weights!\n")

    print("Training finished!")
    print("Final weights are saved at: adas_net_best.pth")

if __name__ == "__main__":
    train()
