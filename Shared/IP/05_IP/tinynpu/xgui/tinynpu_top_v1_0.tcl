# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ACCUM_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ARRAY_COLS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ARRAY_ROWS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BUFFER_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BUFFER_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SCALE_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SHIFT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TILE_SIZE" -parent ${Page_0}


}

proc update_PARAM_VALUE.ACCUM_WIDTH { PARAM_VALUE.ACCUM_WIDTH } {
	# Procedure called to update ACCUM_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACCUM_WIDTH { PARAM_VALUE.ACCUM_WIDTH } {
	# Procedure called to validate ACCUM_WIDTH
	return true
}

proc update_PARAM_VALUE.ARRAY_COLS { PARAM_VALUE.ARRAY_COLS } {
	# Procedure called to update ARRAY_COLS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARRAY_COLS { PARAM_VALUE.ARRAY_COLS } {
	# Procedure called to validate ARRAY_COLS
	return true
}

proc update_PARAM_VALUE.ARRAY_ROWS { PARAM_VALUE.ARRAY_ROWS } {
	# Procedure called to update ARRAY_ROWS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARRAY_ROWS { PARAM_VALUE.ARRAY_ROWS } {
	# Procedure called to validate ARRAY_ROWS
	return true
}

proc update_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to update AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to validate AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_DATA_WIDTH { PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to update AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_DATA_WIDTH { PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to validate AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.BUFFER_ADDR_WIDTH { PARAM_VALUE.BUFFER_ADDR_WIDTH } {
	# Procedure called to update BUFFER_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BUFFER_ADDR_WIDTH { PARAM_VALUE.BUFFER_ADDR_WIDTH } {
	# Procedure called to validate BUFFER_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.BUFFER_DEPTH { PARAM_VALUE.BUFFER_DEPTH } {
	# Procedure called to update BUFFER_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BUFFER_DEPTH { PARAM_VALUE.BUFFER_DEPTH } {
	# Procedure called to validate BUFFER_DEPTH
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.MAX_WIDTH { PARAM_VALUE.MAX_WIDTH } {
	# Procedure called to update MAX_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_WIDTH { PARAM_VALUE.MAX_WIDTH } {
	# Procedure called to validate MAX_WIDTH
	return true
}

proc update_PARAM_VALUE.SCALE_WIDTH { PARAM_VALUE.SCALE_WIDTH } {
	# Procedure called to update SCALE_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SCALE_WIDTH { PARAM_VALUE.SCALE_WIDTH } {
	# Procedure called to validate SCALE_WIDTH
	return true
}

proc update_PARAM_VALUE.SHIFT_WIDTH { PARAM_VALUE.SHIFT_WIDTH } {
	# Procedure called to update SHIFT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SHIFT_WIDTH { PARAM_VALUE.SHIFT_WIDTH } {
	# Procedure called to validate SHIFT_WIDTH
	return true
}

proc update_PARAM_VALUE.TILE_SIZE { PARAM_VALUE.TILE_SIZE } {
	# Procedure called to update TILE_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TILE_SIZE { PARAM_VALUE.TILE_SIZE } {
	# Procedure called to validate TILE_SIZE
	return true
}


proc update_MODELPARAM_VALUE.AXI_ADDR_WIDTH { MODELPARAM_VALUE.AXI_ADDR_WIDTH PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_DATA_WIDTH { MODELPARAM_VALUE.AXI_DATA_WIDTH PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ACCUM_WIDTH { MODELPARAM_VALUE.ACCUM_WIDTH PARAM_VALUE.ACCUM_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACCUM_WIDTH}] ${MODELPARAM_VALUE.ACCUM_WIDTH}
}

proc update_MODELPARAM_VALUE.SCALE_WIDTH { MODELPARAM_VALUE.SCALE_WIDTH PARAM_VALUE.SCALE_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SCALE_WIDTH}] ${MODELPARAM_VALUE.SCALE_WIDTH}
}

proc update_MODELPARAM_VALUE.SHIFT_WIDTH { MODELPARAM_VALUE.SHIFT_WIDTH PARAM_VALUE.SHIFT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SHIFT_WIDTH}] ${MODELPARAM_VALUE.SHIFT_WIDTH}
}

proc update_MODELPARAM_VALUE.ARRAY_ROWS { MODELPARAM_VALUE.ARRAY_ROWS PARAM_VALUE.ARRAY_ROWS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARRAY_ROWS}] ${MODELPARAM_VALUE.ARRAY_ROWS}
}

proc update_MODELPARAM_VALUE.ARRAY_COLS { MODELPARAM_VALUE.ARRAY_COLS PARAM_VALUE.ARRAY_COLS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARRAY_COLS}] ${MODELPARAM_VALUE.ARRAY_COLS}
}

proc update_MODELPARAM_VALUE.BUFFER_DEPTH { MODELPARAM_VALUE.BUFFER_DEPTH PARAM_VALUE.BUFFER_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BUFFER_DEPTH}] ${MODELPARAM_VALUE.BUFFER_DEPTH}
}

proc update_MODELPARAM_VALUE.BUFFER_ADDR_WIDTH { MODELPARAM_VALUE.BUFFER_ADDR_WIDTH PARAM_VALUE.BUFFER_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BUFFER_ADDR_WIDTH}] ${MODELPARAM_VALUE.BUFFER_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.MAX_WIDTH { MODELPARAM_VALUE.MAX_WIDTH PARAM_VALUE.MAX_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_WIDTH}] ${MODELPARAM_VALUE.MAX_WIDTH}
}

proc update_MODELPARAM_VALUE.TILE_SIZE { MODELPARAM_VALUE.TILE_SIZE PARAM_VALUE.TILE_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TILE_SIZE}] ${MODELPARAM_VALUE.TILE_SIZE}
}

