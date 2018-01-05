package provide tincr.cad.util 0.0

package require Tcl 8.5

proc ::tcl::dict::lappend2 {dict args} {
    upvar 1 $dict d
    # Create an entry for the key if it doesn't already exist
    if {![exists $d {*}[lrange $args 0 end-1]]} {
        set d {*}[lrange $args 0 end-1] {}
    }
    with d {*}[lrange $args 0 end-2] {
        ::lappend [lindex $args end-1] [lindex $args end]
    }
}
# Add the above command (lappend2) to the dict ensemble
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {lappend2 ::tcl::dict::lappend2}]

namespace eval ::tcl {
    namespace export \
        source_with_args
}

proc ::tcl::source_with_args {file args} {
    set argv $::argv
    set argc $::argc
    set ::argv $args
    set ::argc [llength $args]
    set code [catch {uplevel [list source $file]} return]
    set ::argv $argv
    set ::argc $argc
    return -code $code $return
}

namespace import ::tcl::*
