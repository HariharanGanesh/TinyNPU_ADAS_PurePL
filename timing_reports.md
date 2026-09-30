# TinyNPU200 Timing Reports

## 1. Post-Route Timing Summary (14x8 Architecture)
This is the full Place & Route timing summary for the highly-optimized 14x8 layout. Constrained to 8.100 ns (123.4 MHz), the design achieved a fully positive slack (green) with **0 failing endpoints**.

```text
| Design Timing Summary
| ---------------------
------------------------------------------------------------------------------------------------

    WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)      THS(ns)  THS Failing Endpoints  THS Total Endpoints     WPWS(ns)     TPWS(ns)  TPWS Failing Endpoints  TPWS Total Endpoints  
    -------      -------  ---------------------  -------------------      -------      -------  ---------------------  -------------------     --------     --------  ----------------------  --------------------  
      0.002        0.000                      0                98569        0.102        0.000                      0                98569        2.800        0.000                       0                 47093  


All user specified timing constraints are met.


------------------------------------------------------------------------------------------------
| Clock Summary
| -------------
------------------------------------------------------------------------------------------------

Clock  Waveform(ns)         Period(ns)      Frequency(MHz)
-----  ------------         ----------      --------------
clk    {0.000 4.050}        8.100           123.457         
```
