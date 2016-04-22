## @file site_pins.tcl
#  @brief Query <CODE>site_pin</CODE> objects in Vivado.
#
#  The <CODE>site_pins</CODE> ensemble provides procs that query a device's site pins.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export site_pins
}

## @brief The <CODE>site_pins</CODE> ensemble encapsulates the <CODE>site_pin</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::site_pins {
    namespace export \
        test \
        get \
        get_info
    namespace ensemble create
}

# TODO: Vivado's "get_site_pins -of $nodes" returns ALL site_pins when $nodes is empty...  
proc ::tincr::site_pins::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device site_pins all.tcl] {*}$args
}

proc ::tincr::site_pins::get { args } {
    return [get_site_pins {*}$args]
}

## Get information about a site pin that can be found by parsing its name.
# @param node The <CODE>site_pin</CODE> object or site pin name to query.
# @param info What information to get about the site pin. Valid values include "site" or "name".
# @return A string containing the specified information.
proc ::tincr::site_pins::get_info { site_pin {info site_pin} } {
    # TODO Expand this proc into separate procs, one for each "info"
    if {[regexp {(\w+)/(\w+)} $site_pin matched site name]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$site_pin\" isn't a valid site_pin name."
    }
}
