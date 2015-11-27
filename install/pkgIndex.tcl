if {[info exists ::env(TINCR_PATH)]} {
	source [file join $::env(TINCR_PATH) tincr pkgIndex.tcl]
}
