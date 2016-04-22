if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.io.design 0.0 {
        source [file join $::env(TINCR_PATH) tincr io design tincr_checkpoints.tcl]
    }
}
