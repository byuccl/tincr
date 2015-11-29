if {[info exists ::env(TINCR_PATH)]} {
	package ifneeded tincr.cad.device 0.0 {
		source [file join $::env(TINCR_PATH) tincr cad device bel_pins.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device bels.tcl]
        source [file join $::env(TINCR_PATH) tincr cad device bel.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device nodes.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device package_pins.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device parts.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device pips.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device site_pins.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device site_pips.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device sites.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device tiles.tcl]
		source [file join $::env(TINCR_PATH) tincr cad device wires.tcl]
	}
}
