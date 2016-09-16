if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.io.library 0.0 {
        source [file join $::env(TINCR_PATH) tincr io library genCellLibrary.tcl]
        source [file join $::env(TINCR_PATH) tincr io library genFamilyInfo.tcl]
    }
}
