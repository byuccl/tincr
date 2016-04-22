if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.cad.design 0.0 {
        source [file join $::env(TINCR_PATH) tincr cad design cells.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design clocks.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design designs.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design lib_cells.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design lib_pins.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design libs.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design macros.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design nets.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design pblocks.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design pins.tcl]
        source [file join $::env(TINCR_PATH) tincr cad design ports.tcl]
    }
}
