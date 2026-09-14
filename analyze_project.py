import os
import csv
import json
import re

ROOT = r"d:\Final year project"
INDEX_DIR = os.path.join(ROOT, "Repository_Index")

APP_MANAGED_DIRS = {
    ".git", ".github", "node_modules", ".venv", "venv", "env", "__pycache__", 
    ".idea", ".vscode", ".cache", ".config", ".metadata", ".settings", ".project",
    ".Xil"
}

APP_MANAGED_EXTS = {
    ".cache", ".hw", ".ip_user_files", ".sim", ".runs", ".gen", ".xpr", ".jou", 
    ".log", ".str", ".pb", ".wdb", ".dcp", ".bit", ".hwh"
}

VERSION_MARKERS = {
    "ADAS_Zonal_Controller", "RISCV_ADAS_NPU300", "RISCV_ADAS_PURE_PL",
    "npu200jb", "npu200jpmax", "tinynpu200_ip_packager", "vivado_2k200j_proj",
    "vivado_hw_test_proj", "vivado_npu200j_green_proj", "vivado_npu200j_proj",
    "Embrix Hackathon", "Polarfire_FPGA_Design_Contest", "cit hackathon"
}

def is_app_managed(path):
    parts = path.split(os.sep)
    for part in parts:
        if part in APP_MANAGED_DIRS:
            return True
        if part.endswith(".sim") or part.endswith(".runs") or part.endswith(".gen") or part.endswith(".cache") or part.endswith(".hw") or part.endswith(".ip_user_files") or part.endswith(".srcs"):
            return True
    
    ext = os.path.splitext(path)[1].lower()
    if ext in APP_MANAGED_EXTS:
        return True
    
    filename = os.path.basename(path).lower()
    if filename.startswith("vivado") and (filename.endswith(".jou") or filename.endswith(".log") or filename.endswith(".str")):
        return True
    
    return False

def is_generated(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in {".bit", ".dcp", ".rpt", ".pb", ".wdb", ".str", ".jou", ".log", ".out", ".bin", ".hwh"}:
        return True
    return False

def get_project_version(path):
    rel = os.path.relpath(path, ROOT)
    parts = rel.split(os.sep)
    for part in parts:
        if part in VERSION_MARKERS:
            return part
    return "Common/Root"

def analyze():
    if not os.path.exists(INDEX_DIR):
        os.makedirs(INDEX_DIR)
        
    inventory = []
    
    for dirpath, dirnames, filenames in os.walk(ROOT):
        for filename in filenames:
            full_path = os.path.join(dirpath, filename)
            rel_path = os.path.relpath(full_path, ROOT)
            ext = os.path.splitext(filename)[1].lower()
            
            app_managed = is_app_managed(full_path)
            generated = is_generated(full_path)
            safe_to_move = not app_managed and not generated
            
            # Additional safety logic
            if filename in {"README.md", "CHANGELOG.md"} and dirpath == ROOT:
                safe_to_move = False # Don't move root readmes
            
            # Simple reference check (very basic)
            deps = []
            if ext in {".tcl", ".py", ".ps1", ".xdc"}:
                safe_to_move = False # Usually scripts expect to be in a certain place relative to other things
                
            entry = {
                "Filename": filename,
                "Full path": full_path,
                "Extension": ext,
                "File type": ext[1:].upper() if ext else "FILE",
                "Parent directory": dirpath,
                "Project/version association": get_project_version(full_path),
                "Application-managed": "YES" if app_managed else "NO",
                "Source-controlled": "Unknown",
                "Generated": "YES" if generated else "NO",
                "Safe to move": "YES" if safe_to_move else "NO",
                "Dependencies/references": ", ".join(deps) if deps else "None detected"
            }
            inventory.append(entry)
            
    # Write CSV
    with open(os.path.join(INDEX_DIR, "file_index.csv"), "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=inventory[0].keys())
        writer.writeheader()
        writer.writerows(inventory)
        
    # Write JSON
    with open(os.path.join(INDEX_DIR, "file_index.json"), "w", encoding="utf-8") as f:
        json.dump(inventory, f, indent=4)
        
    print(f"Analyzed {len(inventory)} files.")

if __name__ == "__main__":
    analyze()
