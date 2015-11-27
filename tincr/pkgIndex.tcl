# If the /c TINCR_PATH environment variable exists, source the TincrCAD and TincrIO <CODE>pkgIndex.tcl</CODE> files.
if {[info exists ::env(TINCR_PATH)]} {
	source [file join $::env(TINCR_PATH) tincr cad pkgIndex.tcl]
	source [file join $::env(TINCR_PATH) tincr io pkgIndex.tcl]
	
    # Register the <CODE>tincr</CODE> package
	package ifneeded tincr 0.0 {
		source [file join $::env(TINCR_PATH) tincr tincr.tcl]
	}
}
