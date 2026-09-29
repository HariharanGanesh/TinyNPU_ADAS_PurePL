#!/usr/bin/env python3
"""
tinynpu_pynq_driver.py
======================
PYNQ-Z2 Python driver for the TinyNPU accelerator.

This driver runs on the ARM Processor System (PS) of the Zynq-7000 and
orchestrates the hardware PL logic via MMIO register accesses, DMA
allocations, and AXI-Stream transfers.

Usage:
------
    from tinynpu_pynq_driver import TinyNPUDriver
    npu = TinyNPUDriver()
    npu.load_weights(weights_int8)
    result = npu.run_inference(activations_int8)
    fps = npu.benchmark(activations_int8, iterations=100)

Requires:
---------
    pynq >= 2.6  (pip install pynq)
    numpy
    An overlay bitstream at BITSTREAM_PATH containing the TinyNPU block.
"""

import numpy as np
import time
try:
    from pynq import Overlay, MMIO, allocate
except ImportError:
    raise ImportError("This driver requires the PYNQ library. Run: pip install pynq")

# =============================================================================
# CSR Register Offset Map (must match axi4_lite_slave.v)
# =============================================================================
ADDR_CTRL             = 0x00
ADDR_STATUS           = 0x04
ADDR_WEIGHT_BASE      = 0x08
ADDR_ACT_BASE         = 0x0C
ADDR_OUT_BASE         = 0x10
ADDR_LAYER_CFG0       = 0x14
ADDR_LAYER_CFG1       = 0x18
ADDR_LAYER_CFG2       = 0x1C
ADDR_PERF_CYCLE_LO    = 0x20
ADDR_PERF_CYCLE_HI    = 0x24
ADDR_IRQ_CTRL         = 0x28
ADDR_M0_CFG           = 0x2C
ADDR_SHIFT_CFG        = 0x30
ADDR_BIAS_CFG         = 0x34
ADDR_PERF_COMPUTE_LO  = 0x38
ADDR_PERF_COMPUTE_HI  = 0x3C
ADDR_PERF_DMA_STALL   = 0x40
ADDR_PERF_OUT_STALL   = 0x44
ADDR_CONF_THRESHOLD   = 0x48
ADDR_CROP_XY          = 0x4C
ADDR_CROP_WH          = 0x50

# CTRL register bit definitions
CTRL_START            = (1 << 0)
CTRL_SOFT_RESET       = (1 << 1)
CTRL_LAYER_TYPE_DW    = (1 << 2)  # Depthwise layer
CTRL_COSINE_SIM_MODE  = (1 << 3)  # Cosine similarity (face recognition)
CTRL_WGT_BANK_SEL     = (1 << 4)  # Weight bank ping-pong select

# STATUS register bit definitions
STATUS_IDLE           = (1 << 0)
STATUS_BUSY           = (1 << 1)
STATUS_DONE           = (1 << 2)
STATUS_ERROR          = (1 << 3)

# Default bitstream path (update to match your project output directory)
BITSTREAM_PATH = "./tinynpu.bit"

# TinyNPU AXI-Lite base address in the Zynq address map
AXILITE_BASE_ADDR = 0x43C0_0000


class TinyNPUDriver:
    """
    PYNQ-Z2 runtime driver for the TinyNPU edge-AI accelerator.

    Responsibilities:
    - Loading the PL bitstream overlay.
    - Allocating contiguous DMA-capable memory buffers.
    - Programming CSR registers via MMIO.
    - Launching inference and polling for completion.
    - Reading back performance profiling counters.
    - Providing face recognition embedding comparison utilities.
    """

    def __init__(self,
                 bitstream_path: str = BITSTREAM_PATH,
                 axilite_base: int = AXILITE_BASE_ADDR,
                 array_size: int = 8,
                 verbose: bool = False):
        """
        Parameters
        ----------
        bitstream_path : str
            Path to the .bit / .hwh overlay files.
        axilite_base : int
            Physical base address of the TinyNPU AXI-Lite interface.
        array_size : int
            Systolic array side length (default 8 for 8x8).
        verbose : bool
            Print detailed register programming log.
        """
        self.array_size = array_size
        self.verbose = verbose

        # Load bitstream overlay
        print(f"[TinyNPU] Loading overlay from: {bitstream_path}")
        self.overlay = Overlay(bitstream_path)
        print("[TinyNPU] Overlay loaded successfully.")

        # MMIO interface to AXI-Lite CSR space
        self.csr = MMIO(axilite_base, 0x100)

        # Soft-reset the accelerator on driver initialisation
        self._soft_reset()

    # =========================================================================
    # Internal Helpers
    # =========================================================================
    def _write(self, offset: int, value: int):
        self.csr.write(offset, int(value) & 0xFFFFFFFF)
        if self.verbose:
            print(f"  [CSR WRITE] @0x{offset:02X} <- 0x{value:08X}")

    def _read(self, offset: int) -> int:
        val = self.csr.read(offset)
        if self.verbose:
            print(f"  [CSR READ]  @0x{offset:02X} -> 0x{val:08X}")
        return val

    def _soft_reset(self):
        """Assert and deassert SOFT_RESET bit to clear FSM state."""
        self._write(ADDR_CTRL, CTRL_SOFT_RESET)
        time.sleep(0.001)
        self._write(ADDR_CTRL, 0)
        print("[TinyNPU] Soft reset complete.")

    def _wait_for_completion(self, timeout_s: float = 5.0) -> bool:
        """Poll STATUS register until DONE bit is set or timeout expires."""
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            status = self._read(ADDR_STATUS)
            if status & STATUS_DONE:
                return True
            if status & STATUS_ERROR:
                raise RuntimeError("[TinyNPU] Hardware reported STATUS_ERROR!")
        raise TimeoutError(f"[TinyNPU] Inference timed out after {timeout_s}s.")

    # =========================================================================
    # Layer Configuration
    # =========================================================================
    def configure_layer(self,
                        kernel_size: int = 1,
                        stride: int = 1,
                        padding: int = 0,
                        act_sel: int = 0,
                        in_channels: int = 8,
                        out_channels: int = 8,
                        input_height: int = 1,
                        input_width: int = 1,
                        m0: int = 0x40000000,
                        n_shift: int = 31,
                        bias: int = 0,
                        layer_type: int = 0,
                        cosine_sim_mode: bool = False):
        """
        Program all layer configuration CSRs.

        Parameters
        ----------
        act_sel   : 0=ReLU, 1=LeakyReLU, 2=Identity(bypass)
        layer_type: 0=standard conv/matmul, 1=depthwise
        cosine_sim_mode: True for face embedding comparison
        """
        cfg0 = (act_sel << 24) | (padding << 16) | (stride << 8) | kernel_size
        cfg1 = ((out_channels & 0xFFFF) << 16) | (in_channels & 0xFFFF)
        cfg2 = ((input_height & 0xFFFF) << 16) | (input_width & 0xFFFF)

        ctrl = (CTRL_LAYER_TYPE_DW if layer_type == 1 else 0) | \
               (CTRL_COSINE_SIM_MODE if cosine_sim_mode else 0)

        self._write(ADDR_LAYER_CFG0, cfg0)
        self._write(ADDR_LAYER_CFG1, cfg1)
        self._write(ADDR_LAYER_CFG2, cfg2)
        self._write(ADDR_M0_CFG, m0 & 0xFFFFFFFF)
        self._write(ADDR_SHIFT_CFG, n_shift)
        self._write(ADDR_BIAS_CFG, bias & 0xFFFFFFFF)
        self._write(ADDR_CTRL, ctrl)

    def configure_crop(self, x: int = 0, y: int = 0,
                        w: int = 0, h: int = 0, enable: bool = False):
        """
        Configure the spatial crop preprocessing window.
        Set enable=False to disable cropping (all pixels pass).
        """
        crop_xy = ((y & 0xFFFF) << 16) | (x & 0xFFFF)
        crop_wh = ((h & 0xFFFF) << 16) | (w & 0xFFFF)
        self._write(ADDR_CROP_XY, crop_xy)
        self._write(ADDR_CROP_WH, crop_wh)
        # Crop enable is wired through the crop_en port; CSR bit unused here.
        # Set w=h=0 to implicitly disable.
        if not enable:
            self._write(ADDR_CROP_WH, 0)

    def configure_confidence_threshold(self, threshold: int = 32):
        """
        Set the hardware confidence score filter threshold (0-255).
        Only outputs with score >= threshold will be written to the output FIFO.
        Set to 0 to disable filtering.
        """
        self._write(ADDR_CONF_THRESHOLD, threshold & 0xFF)

    # =========================================================================
    # Weight Loading
    # =========================================================================
    def load_weights(self, weights: np.ndarray, bank: int = 0):
        """
        DMA-transfer INT8 weight array to TinyNPU weight buffer.

        Parameters
        ----------
        weights : np.ndarray
            INT8 array of shape (out_channels, in_channels) or
            (out_ch, in_ch, kH, kW) for conv layers.
            Will be flattened in row-major order before transfer.
        bank : int
            Target weight bank (0 or 1). The ACTIVE compute bank
            should be the opposite of this value.
        """
        assert weights.dtype == np.int8, "Weights must be INT8 (np.int8)"
        flat = weights.flatten().astype(np.int8)
        n = len(flat)

        # Allocate contiguous physical memory for DMA
        wgt_buf = allocate(shape=(n,), dtype=np.int8)
        np.copyto(wgt_buf, flat)

        # Program weight base address and bank select, then trigger DMA
        self._write(ADDR_WEIGHT_BASE, wgt_buf.physical_address)
        # Set weight bank select bit in CTRL
        ctrl_val = self._read(ADDR_CTRL)
        if bank == 1:
            ctrl_val |= CTRL_WGT_BANK_SEL
        else:
            ctrl_val &= ~CTRL_WGT_BANK_SEL
        self._write(ADDR_CTRL, ctrl_val)

        if self.verbose:
            print(f"[TinyNPU] Loaded {n} weights to bank {bank} "
                  f"@ phys 0x{wgt_buf.physical_address:08X}")
        wgt_buf.freebuffer()

    # =========================================================================
    # Inference
    # =========================================================================
    def run_inference(self,
                      activations: np.ndarray,
                      timeout_s: float = 5.0) -> np.ndarray:
        """
        Run one inference pass through TinyNPU.

        Parameters
        ----------
        activations : np.ndarray
            INT8 activation input (1D or 2D, will be flattened).
        timeout_s : float
            Maximum wait time for completion.

        Returns
        -------
        np.ndarray
            INT8 output activations from the output buffer.
        """
        assert activations.dtype == np.int8, "Activations must be INT8 (np.int8)"
        flat_in = activations.flatten().astype(np.int8)
        n_in = len(flat_in)

        # Determine expected output size from CSR
        cfg1 = self._read(ADDR_LAYER_CFG1)
        out_channels = (cfg1 >> 16) & 0xFFFF
        n_out = max(out_channels, self.array_size)

        # Allocate DMA buffers
        act_buf = allocate(shape=(n_in,), dtype=np.int8)
        out_buf = allocate(shape=(n_out,), dtype=np.int8)
        np.copyto(act_buf, flat_in)

        # Program addresses
        self._write(ADDR_ACT_BASE, act_buf.physical_address)
        self._write(ADDR_OUT_BASE, out_buf.physical_address)

        # Trigger execution
        self._write(ADDR_CTRL, self._read(ADDR_CTRL) | CTRL_START)

        # Wait for DONE
        self._wait_for_completion(timeout_s)

        # Collect result
        result = np.array(out_buf, dtype=np.int8).copy()

        act_buf.freebuffer()
        out_buf.freebuffer()
        return result

    # =========================================================================
    # Face Recognition: Cosine Similarity
    # =========================================================================
    def compare_embeddings(self,
                           query_emb: np.ndarray,
                           db_embeddings: np.ndarray,
                           top_k: int = 1) -> list:
        """
        Compare a query face embedding against a database of stored templates
        using hardware-accelerated INT8 dot products via the cosine-sim mode.

        NOTE: Similarity RANKING and final argmax are performed on ARM CPU
        since they involve irregular control flow (sorting) not suitable for RTL.

        Parameters
        ----------
        query_emb   : np.ndarray of shape (D,) in INT8
        db_embeddings: np.ndarray of shape (N, D) where N=database size, D=embedding dim
        top_k       : number of top matches to return

        Returns
        -------
        list of (index, score) tuples sorted by score descending
        """
        assert query_emb.dtype == np.int8, "Embeddings must be INT8"
        assert db_embeddings.dtype == np.int8, "DB must be INT8"

        n_templates, emb_dim = db_embeddings.shape
        scores = []

        # Configure NPU for cosine-similarity mode
        self.configure_layer(
            kernel_size=1, stride=1, padding=0,
            act_sel=2,  # Identity (no ReLU — scores can be negative)
            in_channels=emb_dim,
            out_channels=1,  # Single dot-product score per template
            input_height=1,
            input_width=1,
            cosine_sim_mode=True
        )
        self.configure_confidence_threshold(0)  # No threshold in embedding mode

        for i, template in enumerate(db_embeddings):
            # Load template as weight bank
            self.load_weights(template.reshape(1, -1), bank=0)
            # Run dot product inference
            raw_score = self.run_inference(query_emb)
            scores.append((i, int(raw_score[0])))

        # Sort descending by score on ARM CPU
        scores.sort(key=lambda x: x[1], reverse=True)
        return scores[:top_k]

    # =========================================================================
    # Performance Profiling
    # =========================================================================
    def read_performance_counters(self) -> dict:
        """
        Read all hardware performance counters from CSRs.

        Returns
        -------
        dict with keys: cycle_count, compute_count, dma_stall_count,
                        out_stall_count, compute_efficiency_pct
        """
        cycle_lo   = self._read(ADDR_PERF_CYCLE_LO)
        cycle_hi   = self._read(ADDR_PERF_CYCLE_HI)
        compute_lo = self._read(ADDR_PERF_COMPUTE_LO)
        compute_hi = self._read(ADDR_PERF_COMPUTE_HI)
        dma_stall  = self._read(ADDR_PERF_DMA_STALL)
        out_stall  = self._read(ADDR_PERF_OUT_STALL)

        total_cycles   = (cycle_hi << 32) | cycle_lo
        compute_cycles = (compute_hi << 32) | compute_lo

        efficiency = (compute_cycles / total_cycles * 100) if total_cycles > 0 else 0.0

        return {
            "cycle_count"           : total_cycles,
            "compute_count"         : compute_cycles,
            "dma_stall_count"       : dma_stall,
            "out_stall_count"       : out_stall,
            "compute_efficiency_pct": round(efficiency, 2)
        }

    def benchmark(self,
                  activations: np.ndarray,
                  iterations: int = 100,
                  clock_mhz: float = 150.0) -> dict:
        """
        Benchmark TinyNPU inference latency and throughput.

        Parameters
        ----------
        activations : np.ndarray  Input INT8 data.
        iterations  : int         Number of inference passes.
        clock_mhz   : float       PL clock frequency in MHz.

        Returns
        -------
        dict with latency_ms, throughput_fps, compute_efficiency_pct
        """
        t_start = time.time()
        for _ in range(iterations):
            self.run_inference(activations)
        t_total = time.time() - t_start

        latency_ms = (t_total / iterations) * 1000
        fps        = 1000.0 / latency_ms

        perf = self.read_performance_counters()
        cycle_latency_ms = (perf["cycle_count"] / (clock_mhz * 1e6)) * 1000

        print(f"\n[TinyNPU Benchmark Results]")
        print(f"  Wall-clock latency  : {latency_ms:.3f} ms/inference")
        print(f"  Hardware cycle lat. : {cycle_latency_ms:.3f} ms ({perf['cycle_count']} cycles @ {clock_mhz} MHz)")
        print(f"  Throughput          : {fps:.1f} FPS")
        print(f"  Compute efficiency  : {perf['compute_efficiency_pct']:.1f}%")
        print(f"  DMA stall cycles    : {perf['dma_stall_count']}")
        print(f"  Output stall cycles : {perf['out_stall_count']}")

        return {
            "latency_ms"            : latency_ms,
            "throughput_fps"        : fps,
            "cycle_latency_ms"      : cycle_latency_ms,
            "compute_efficiency_pct": perf["compute_efficiency_pct"],
            "dma_stall_count"       : perf["dma_stall_count"],
            "out_stall_count"       : perf["out_stall_count"]
        }
