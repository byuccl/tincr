if {[info exists ::env(TINCR_PATH)]} {
	package ifneeded tincr.cad.router 0.0 {
		source [file join $::env(TINCR_PATH) tincr cad router examples.tcl]
	}
}
