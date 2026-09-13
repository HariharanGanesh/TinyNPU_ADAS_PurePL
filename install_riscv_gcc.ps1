$ErrorActionPreference = "Stop"
$ToolchainUrl = "https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-1/xpack-riscv-none-elf-gcc-14.2.0-1-win32-x64.zip"
$ZipFile = "D:\Final year project\riscv-gcc.zip"
$ExtractDir = "D:\Final year project\riscv-toolchain"

Write-Host "Downloading RISC-V GCC Toolchain (this may take a minute)..."
Invoke-WebRequest -Uri $ToolchainUrl -OutFile $ZipFile

Write-Host "Extracting Toolchain..."
Expand-Archive -Path $ZipFile -DestinationPath $ExtractDir -Force

Write-Host "Cleaning up zip file..."
Remove-Item $ZipFile

Write-Host "Done! The toolchain is installed in $ExtractDir"
