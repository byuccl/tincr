package provide tincr.cad.util 0.0

package require Tcl 8.5
package require struct 2.1

namespace eval ::tincr {
    namespace export \
        parse_argsx \
        tokenizer
}

## Parses a list of arguments and generates a Usage statement when wrong
# tincr::parse_args {?{a|b}? c} {d ?e? {f|{g h}}} {i ?j? {k l}...}
proc ::tincr::parse_argsx {flags options statements args} {
    # Use a dict to store mutually exclusive arguments
    # Use a set to store optional arguments
    
    puts [uplevel {info script}]
}
