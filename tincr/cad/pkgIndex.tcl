if {[info exists ::env(TINCR_PATH)]} {
    source [file join $::env(TINCR_PATH) tincr cad cache pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr cad design pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr cad device pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr cad placer pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr cad router pkgIndex.tcl]
    source [file join $::env(TINCR_PATH) tincr cad util pkgIndex.tcl]
    
    package ifneeded tincr.cad 0.0 {
        source [file join $::env(TINCR_PATH) tincr cad tincr.cad.tcl]
    }
}