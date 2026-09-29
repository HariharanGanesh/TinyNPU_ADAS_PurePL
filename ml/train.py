import torch
from torch.utils.data import DataLoader
from tinyvelocity import TinyVelocity
from dataset import DummyCarDataset
from loss import TinyVelocityLoss
import time

def train():
    # 1. Setup Device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"==========================================")
    print(f" Starting TinyVelocity Training Pipeline")
    print(f" Hardware: {device}")
    print(f"==========================================")

    # 2. Initialize Model
    # num_classes=1 because we are only detecting 'Cars'
    model = TinyVelocity(num_classes=1).to(device)
    
    # 3. Setup Dataset and DataLoader
    # We use our Dummy Dataset for testing the pipeline. 
    # In production, replace this with a real Dataset (e.g., COCO or custom cars)
    train_dataset = DummyCarDataset(size=5000)
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=0)
    
    # 4. Setup Loss and Optimizer
    criterion = TinyVelocityLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    
    epochs = 5
    best_loss = float('inf')

    # 5. Training Loop
    print("\nStarting Training Loop (Heatmap Center Detection)...")
    for epoch in range(epochs):
        model.train()
        epoch_loss = 0.0
        start_time = time.time()
        
        for batch_idx, (images, gt_heatmaps) in enumerate(train_loader):
            images = images.to(device)
            gt_heatmaps = gt_heatmaps.to(device)
            
            optimizer.zero_grad()
            
            # Forward Pass: Predict heatmap
            pred_hm, pred_off, pred_wh = model(images)
            
            # Calculate Focal Loss on the heatmap
            loss = criterion(pred_hm, gt_heatmaps)
            
            # Backward Pass
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            
            if batch_idx % 20 == 0:
                print(f"Epoch [{epoch+1}/{epochs}] Batch [{batch_idx}/{len(train_loader)}] Loss: {loss.item():.4f}")
                
        avg_loss = epoch_loss / len(train_loader)
        epoch_time = time.time() - start_time
        print(f"\n--- Epoch {epoch+1} Complete | Avg Loss: {avg_loss:.4f} | Time: {epoch_time:.2f}s ---")
        
        # Save best model weights
        if avg_loss < best_loss:
            best_loss = avg_loss
            torch.save(model.state_dict(), "tinyvelocity_cars_best.pth")
            print(">>> Saved new best model weights!\n")

    print("Training finished! The model learned to identify cars via Heatmaps.")
    print("Final weights are saved at: D:\\Final year project\\ml\\tinyvelocity_cars_best.pth")

if __name__ == "__main__":
    train()
