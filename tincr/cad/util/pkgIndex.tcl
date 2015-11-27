if {[info exists ::env(TINCR_PATH)]} {
	package ifneeded tincr.cad.util 0.0 {
		source [file join $::env(TINCR_PATH) tincr cad util argument_parser.tcl]
		source [file join $::env(TINCR_PATH) tincr cad util cache.tcl]
		source [file join $::env(TINCR_PATH) tincr cad util primitive_def_parser.tcl]
		source [file join $::env(TINCR_PATH) tincr cad util tcl.tcl]
		source [file join $::env(TINCR_PATH) tincr cad util util.tcl]
		source [file join $::env(TINCR_PATH) tincr cad util vivado.tcl]
	}
}
