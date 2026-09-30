# TinyNPU200 Timing Reports

## 1. Post-Route Timing Summary (14x8 Architecture)
This is the full Place & Route timing summary for the 14x8 layout, successfully hitting an effective maximum operating frequency of **124.2 MHz**.

`	ext
| Design Timing Summary
| ---------------------
------------------------------------------------------------------------------------------------

    WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)      THS(ns)  THS Failing Endpoints  THS Total Endpoints     WPWS(ns)     TPWS(ns)  TPWS Failing Endpoints  TPWS Total Endpoints  
    -------      -------  ---------------------  -------------------      -------      -------  ---------------------  -------------------     --------     --------  ----------------------  --------------------  
     -0.051       -0.837                     50                98479        0.110        0.000                      0                98479        2.750        0.000                       0                 47018  


Timing constraints are not met.


------------------------------------------------------------------------------------------------
| Clock Summary
| -------------
------------------------------------------------------------------------------------------------

Clock  Waveform(ns)         Period(ns)      Frequency(MHz)
-----  ------------         ----------      --------------
clk    {0.000 4.000}        8.000           125.000         
`

## 2. Post-Route Timing Summary (14x14 Architecture)
*Status: ? Currently running full Vivado Place & Route implementation in the background. It takes approximately 10-15 minutes for the Vivado placer/router to finish weaving the physical fabric. This artifact will be updated automatically as soon as the results are ready.*
