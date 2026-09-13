# ==============================================================================
# DRC Waiver: Digilent dvi2rgb v2.0 pRst OOC synthesis trimming bug
# The pRst net inside dvi2rgb is trimmed during OOC synthesis with Vivado 2025.1
# when aRst input is treated as don't-care. Downgrade to WARNING so place_design
# and write_bitstream can proceed without crashing.
# ==============================================================================
set_property SEVERITY {WARNING} [get_drc_checks {NDRV-1}]
