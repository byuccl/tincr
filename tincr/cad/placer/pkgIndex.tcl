if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.cad.placer 0.0 {
        source [file join $::env(TINCR_PATH) tincr cad placer examples.tcl]
    }
}
