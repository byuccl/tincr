if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.io.device 0.0 {
        source [file join $::env(TINCR_PATH) tincr io device xdlrc.tcl]
    }
}
