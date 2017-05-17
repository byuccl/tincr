if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.io.device 0.0 {
        source [file join $::env(TINCR_PATH) tincr io device xdlrc.tcl]
        source [file join $::env(TINCR_PATH) tincr io device family_info.tcl]
        source [file join $::env(TINCR_PATH) tincr io device cell_library.tcl]
        source [file join $::env(TINCR_PATH) tincr io device device_info.tcl]
    }
}
