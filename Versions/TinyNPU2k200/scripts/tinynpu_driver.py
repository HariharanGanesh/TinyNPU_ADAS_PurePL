"""
tinynpu_driver.py — PYNQ Python Driver for TinyNPU System
==========================================================
Run on PYNQ-Z2 board with Python 3.

Usage:
    from tinynpu_driver import TinyNPU
    npu = TinyNPU()
    result = npu.run(input_data)

Requirements:
    pip install pynq numpy
"""

import numpy as np
import time

try:
    from pynq import Overlay, allocate
    PYNQ_AVAILABLE = True
except ImportError:
    PYNQ_AVAILABLE = False
    print("WARNING: PYNQ not available. Running in simulation mode.")


# =============================================================================
# TinyNPU AXI-Lite Register Map
# (matches rtl/top/tinynpu_top.v register definitions)
# =============================================================================
REG_CTRL       = 0x00  # Control: [0]=start, [1]=reset
REG_STATUS     = 0x04  # Status:  [0]=busy, [1]=done, [2]=error
REG_IN_ROWS    = 0x08  # Input rows
REG_IN_COLS    = 0x0C  # Input cols
REG_IN_CH      = 0x10  # Input channels
REG_OUT_CH     = 0x14  # Output channels
REG_KERNEL_SZ  = 0x18  # Kernel size
REG_STRIDE     = 0x1C  # Stride
REG_PADDING    = 0x20  # Padding
REG_OP_MODE    = 0x24  # Op: 0=conv, 1=depthwise, 2=pointwise
REG_QUANT_SCALE = 0x28 # Requant scale (fixed point Q8.8)
REG_THRESHOLD  = 0x2C  # Detection confidence threshold
REG_IRQ_STATUS = 0x30  # Interrupt status (write 1 to clear)
REG_PERF_CYCLES = 0x34 # Performance counter: clock cycles

CTRL_START     = (1 << 0)
CTRL_RESET     = (1 << 1)
STATUS_BUSY    = (1 << 0)
STATUS_DONE    = (1 << 1)
STATUS_ERROR   = (1 << 2)


class TinyNPUOverlay(Overlay):
    """Extended PYNQ Overlay with TinyNPU-specific helpers."""
    def __init__(self, bitfile="tinynpu.bit"):
        super().__init__(bitfile)


class TinyNPU:
    """
    High-level Python driver for TinyNPU on PYNQ-Z2.
    
    Architecture:
        PS7 GP0 --AXI-Lite--> NPU control registers
        PS7 GP0 --AXI-Lite--> AXI DMA control
        DMA MM2S --AXI-Stream--> NPU input
        NPU output --AXI-Stream--> DMA S2MM
        DMA MM2S/S2MM --AXI--> PS7 HP0 (DDR)
    """

    def __init__(self, bitfile="tinynpu.bit", clock_mhz=100):
        self.clock_mhz   = clock_mhz
        self.clock_period = 1.0 / (clock_mhz * 1e6)  # seconds
        
        if PYNQ_AVAILABLE:
            print(f"Loading overlay: {bitfile}")
            self.ol  = Overlay(bitfile)
            self.dma = self.ol.axi_dma_0
            self.npu = self.ol.tinynpu100_0
            print("✅ Overlay loaded successfully")
            self._reset_npu()
        else:
            self.ol  = None
            self.dma = None
            self.npu = None
            print("⚠  Simulation mode (PYNQ not available)")

    # -------------------------------------------------------------------------
    # Register Access
    # -------------------------------------------------------------------------
    def _write_reg(self, offset, value):
        if self.npu:
            self.npu.write(offset, int(value))

    def _read_reg(self, offset):
        if self.npu:
            return self.npu.read(offset)
        return 0

    def _reset_npu(self):
        """Issue soft reset to NPU."""
        self._write_reg(REG_CTRL, CTRL_RESET)
        time.sleep(0.001)
        self._write_reg(REG_CTRL, 0)

    # -------------------------------------------------------------------------
    # Layer Configuration
    # -------------------------------------------------------------------------
    def configure_layer(self, in_rows, in_cols, in_ch, out_ch,
                         kernel_sz=3, stride=1, padding=1,
                         op_mode=0, quant_scale=128, threshold=128):
        """
        Configure NPU for a convolution layer.
        
        Args:
            in_rows, in_cols: Input feature map spatial dimensions
            in_ch:    Input channels
            out_ch:   Output channels
            kernel_sz: Kernel size (1 or 3)
            stride:    Convolution stride
            padding:   Zero-padding amount
            op_mode:   0=standard conv, 1=depthwise, 2=pointwise
            quant_scale: Requantization multiplier (INT8, Q8.8 format)
            threshold:   Detection confidence threshold (0-255 UINT8)
        """
        self._write_reg(REG_IN_ROWS,    in_rows)
        self._write_reg(REG_IN_COLS,    in_cols)
        self._write_reg(REG_IN_CH,      in_ch)
        self._write_reg(REG_OUT_CH,     out_ch)
        self._write_reg(REG_KERNEL_SZ,  kernel_sz)
        self._write_reg(REG_STRIDE,     stride)
        self._write_reg(REG_PADDING,    padding)
        self._write_reg(REG_OP_MODE,    op_mode)
        self._write_reg(REG_QUANT_SCALE, quant_scale)
        self._write_reg(REG_THRESHOLD,  threshold)

    # -------------------------------------------------------------------------
    # DMA Transfer
    # -------------------------------------------------------------------------
    def run(self, input_data: np.ndarray, timeout_s: float = 1.0) -> np.ndarray:
        """
        Run inference on input_data via DMA → NPU → DMA.
        
        Args:
            input_data: numpy array, dtype=np.int8 or np.uint8
                        Shape: (H, W, C) or flat (N,)
            timeout_s:  Maximum time to wait for NPU completion
            
        Returns:
            output_data: numpy array (int8), NPU output
        """
        if not PYNQ_AVAILABLE:
            return self._simulate(input_data)

        # Flatten and ensure correct dtype
        flat_in = input_data.flatten().astype(np.int8)
        n_bytes = flat_in.nbytes
        
        # Allocate DMA-accessible buffers (contiguous physical memory)
        in_buf  = allocate(shape=(len(flat_in),), dtype=np.int8)
        out_buf = allocate(shape=(len(flat_in),), dtype=np.int8)  # conservative size
        
        # Copy input to DMA buffer
        np.copyto(in_buf, flat_in)

        t_start = time.perf_counter()
        
        # Start NPU
        self._write_reg(REG_CTRL, CTRL_START)
        
        # Launch DMA transfers (non-blocking)
        self.dma.sendchannel.transfer(in_buf)
        self.dma.recvchannel.transfer(out_buf)
        
        # Wait for completion
        self.dma.sendchannel.wait()
        self.dma.recvchannel.wait()
        
        t_end = time.perf_counter()
        
        # Read performance counter
        cycles = self._read_reg(REG_PERF_CYCLES)
        latency_us = (t_end - t_start) * 1e6
        hw_latency_us = cycles / (self.clock_mhz * 1e6) * 1e6
        
        print(f"  Latency (wall):     {latency_us:.1f} µs")
        print(f"  Latency (HW cycles): {cycles} cycles = {hw_latency_us:.1f} µs @ {self.clock_mhz}MHz")
        
        # Clear interrupt
        self._write_reg(REG_IRQ_STATUS, 0x1)
        
        # Copy result
        result = np.array(out_buf, dtype=np.int8)
        
        # Free DMA buffers
        in_buf.freebuffer()
        out_buf.freebuffer()
        
        return result

    # -------------------------------------------------------------------------
    # YOLOv8n Detection Head Helper
    # -------------------------------------------------------------------------
    def detect(self, frame: np.ndarray,
               input_shape=(1, 160, 160, 3),
               conf_threshold=0.5,
               num_classes=80) -> list:
        """
        Run YOLOv8n-like detection on a frame.
        
        Args:
            frame:          Input image (H, W, 3) uint8
            input_shape:    Model input shape (N, H, W, C)
            conf_threshold: Minimum confidence score
            num_classes:    Number of object classes
            
        Returns:
            detections: list of dicts with 'bbox', 'conf', 'class_id'
        """
        _, in_h, in_w, in_c = input_shape
        
        # Resize and preprocess
        import cv2
        resized = cv2.resize(frame, (in_w, in_h))
        quantized = (resized.astype(np.float32) / 2.0 - 64).astype(np.int8)
        
        # Configure NPU for first conv layer (example: 3→16, 3x3, stride=1)
        self.configure_layer(
            in_rows=in_h, in_cols=in_w, in_ch=3, out_ch=16,
            kernel_sz=3, stride=1, padding=1, op_mode=0,
            quant_scale=128, threshold=int(conf_threshold * 255)
        )
        
        # Run inference
        t0 = time.perf_counter()
        output = self.run(quantized)
        t1 = time.perf_counter()
        
        total_latency_us = (t1 - t0) * 1e6
        print(f"Total end-to-end latency: {total_latency_us:.1f} µs")
        
        # Parse detections from output buffer
        detections = self._parse_detections(output, conf_threshold, num_classes)
        return detections

    def _parse_detections(self, output, conf_threshold, num_classes):
        """Parse raw NPU output into detection boxes."""
        detections = []
        # Each detection: [cx, cy, w, h, conf, cls_scores...]
        det_size = 5 + num_classes
        n_dets = len(output) // det_size
        
        for i in range(n_dets):
            base = i * det_size
            if base + det_size > len(output):
                break
            
            det = output[base:base+det_size].astype(np.float32) / 127.0
            conf = float(det[4])
            
            if conf > conf_threshold:
                cls_id = int(np.argmax(det[5:]))
                cls_conf = float(det[5 + cls_id])
                
                detections.append({
                    'bbox':     [float(x) for x in det[:4]],
                    'conf':     conf * cls_conf,
                    'class_id': cls_id
                })
        
        return detections

    # -------------------------------------------------------------------------
    # Simulation mode (no hardware)
    # -------------------------------------------------------------------------
    def _simulate(self, input_data):
        print("  [SIM] Running NPU simulation (no hardware)")
        time.sleep(0.00001)  # simulate ~10µs
        return np.zeros(len(input_data.flatten()), dtype=np.int8)

    # -------------------------------------------------------------------------
    # Diagnostics
    # -------------------------------------------------------------------------
    def status(self):
        """Print NPU status registers."""
        stat = self._read_reg(REG_STATUS)
        cycles = self._read_reg(REG_PERF_CYCLES)
        print(f"NPU Status Register: 0x{stat:08X}")
        print(f"  BUSY:  {bool(stat & STATUS_BUSY)}")
        print(f"  DONE:  {bool(stat & STATUS_DONE)}")
        print(f"  ERROR: {bool(stat & STATUS_ERROR)}")
        print(f"  Last run: {cycles} cycles ({cycles/self.clock_mhz:.1f} µs @ {self.clock_mhz}MHz)")

    def benchmark(self, n_runs=100, payload_bytes=76800):
        """
        Benchmark NPU throughput.
        Args:
            n_runs: Number of inference runs
            payload_bytes: Input size in bytes (default: 160x160x3)
        """
        print(f"\n=== TinyNPU Benchmark ({n_runs} runs, {payload_bytes}B input) ===")
        dummy = np.zeros(payload_bytes, dtype=np.int8)
        
        self.configure_layer(160, 160, 3, 16, kernel_sz=3, stride=1, padding=1)
        
        latencies = []
        for i in range(n_runs):
            t0 = time.perf_counter()
            self.run(dummy)
            t1 = time.perf_counter()
            latencies.append((t1 - t0) * 1e6)
        
        latencies = np.array(latencies)
        print(f"  Min latency:  {latencies.min():.1f} µs")
        print(f"  Max latency:  {latencies.max():.1f} µs")
        print(f"  Mean latency: {latencies.mean():.1f} µs")
        print(f"  P95 latency:  {np.percentile(latencies, 95):.1f} µs")
        print(f"  Throughput:   {1e6/latencies.mean():.0f} inferences/sec")
        return latencies


# =============================================================================
# Quick test (run on PYNQ board)
# =============================================================================
if __name__ == "__main__":
    print("TinyNPU PYNQ Driver — Quick Test")
    print("=" * 40)
    
    npu = TinyNPU(bitfile="tinynpu.bit", clock_mhz=100)
    npu.status()
    
    # Benchmark
    npu.benchmark(n_runs=10, payload_bytes=160*160*3)
