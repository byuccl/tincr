if {[info exists ::env(TINCR_PATH)]} {
    package ifneeded tincr.cad.cache 0.0 {
        source [file join $::env(TINCR_PATH) tincr cad cache cache.tcl]
        foreach def [glob -dir [file join $::env(TINCR_PATH) tincr cad cache cache_definitions] *.tcl] {
            source $def
        }
    }
}
