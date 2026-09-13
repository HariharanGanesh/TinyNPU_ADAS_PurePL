# AEGIS-NPU System Block Diagram

Here is the system block diagram for your proposal. You can include this directly in your markdown submission, or render it using any Mermaid viewer to generate an image for your final PDF/presentation.

```mermaid
graph TD
    %% Styling
    classDef sensors fill:#1f2937,stroke:#3b82f6,stroke-width:2px,color:#fff;
    classDef fabric fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#fff;
    classDef riscv fill:#701a75,stroke:#d946ef,stroke-width:2px,color:#fff;
    classDef mem fill:#7c2d12,stroke:#f97316,stroke-width:2px,color:#fff;
    classDef out fill:#1f2937,stroke:#94a3b8,stroke-width:2px,color:#fff;

    %% Sensor Layer
    subgraph SENSORS ["Sensor Ingestion (Real-World)"]
        cam[MIPI CSI-2 Camera]:::sensors
        lidar[Ethernet/UDP LiDAR]:::sensors
        radar[LVDS Radar]:::sensors
        imu[SPI 6-DoF IMU]:::sensors
        gnss[UART GNSS Receiver]:::sensors
    end

    %% FPGA Fabric Layer
    subgraph PL ["PolarFire FPGA Fabric (Programmable Logic)"]
        direction TB
        
        %% Ingestion
        ingest[Zero-Copy Hardware Ingestion\nFIFOs & Deserializers]:::fabric
        
        %% Preprocessing
        isp[Image Signal Processing\nBayer, Undistort, Norm]:::fabric
        pfe[LiDAR Pillar Feature Encoder\nVoxelization]:::fabric
        preint[IMU Preintegration\nSO3 Lie Algebra]:::fabric
        
        %% Time-Multiplexed NPU Overlay
        subgraph TM_OVERLAY ["Time-Multiplexed Hardware Overlay (< 5ms)"]
            direction LR
            npu[CoreVectorBlox + 16x16 Systolic\n3D Det, Face, Anomaly]:::fabric
            slam[ORB 8-PPC + ICP SLAM Engine]:::fabric
            eskf[21-State ESKF\nCholesky Array]:::fabric
            track[ByteTrack + HW Hungarian]:::fabric
        end
        
        %% Fusion
        msfc[Multi-Sensor Fusion Core\nTriple Modular Redundancy]:::fabric
        cordic[CORDIC XYZ Projector]:::fabric
    end

    %% RISC-V MSS Layer
    subgraph MSS ["PolarFire Microprocessor Subsystem (MSS)"]
        direction TB
        l2[2MB L2 Cache Scratchpad\nZero-DRAM Target]:::mem
        
        u54_1[U54 Core 1: Bare-Metal\nGTSAM Pose Graph]:::riscv
        u54_2[U54 Core 2: Bare-Metal\nTrack ID Database]:::riscv
        e51[E51 Monitor Core\nReal-Time Watchdog]:::riscv
        u54_3[U54 Core 3/4: Linux\nROS2 / Network Stack]:::riscv
    end

    %% External Memory & Output
    subgraph OUTPUT ["External Interfaces"]
        ddr[LPDDR4 Memory\nModel Weights Storage]:::mem
        pcie[PCIe Gen2 x4\nHost Uplink]:::out
        eth[Gigabit Ethernet TSN\nTactical Data Link]:::out
    end

    %% Connections
    cam --> ingest
    lidar --> ingest
    radar --> ingest
    imu --> ingest
    gnss --> ingest

    ingest --> isp
    ingest --> pfe
    ingest --> preint
    ingest --> eskf

    isp --> TM_OVERLAY
    pfe --> TM_OVERLAY
    preint --> eskf

    TM_OVERLAY --> msfc
    msfc --> cordic
    cordic --> l2

    l2 <--> u54_1
    l2 <--> u54_2
    l2 <--> e51
    l2 <--> u54_3
    
    u54_3 <--> ddr
    u54_3 --> pcie
    u54_3 --> eth

    %% FIC Bridges (Text labels on lines)
    TM_OVERLAY == "FIC0 (AXI4)" ==> l2
```
