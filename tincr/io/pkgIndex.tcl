if {[info exists ::env(TINCR_PATH)]} {
    source [file join $::env(TINCR_PATH) tincr io design pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr io device pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr io library pkgIndex.tcl]
    
    package ifneeded tincr.io 0.0 {
        source [file join $::env(TINCR_PATH) tincr io tincr.io.tcl]
    }
}
