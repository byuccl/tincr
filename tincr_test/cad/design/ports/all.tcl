package require Tcl 8.5
package require tcltest
package require tincr

switch $::tcl_platform(platform) {
    windows {
        ::tcltest::interpreter [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat]
    }
    unix {
        
    }
}

::tcltest::configure -testdir [file join $::env(TINCR_PATH) tincr_test cad design ports]

::tcltest::configure {*}$::argv

::tcltest::runAllTests
