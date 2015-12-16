## @file site_type.tcl
#  @brief Represents the type of a <CODE>site</CODE> object in Vivado.
#
#  The <CODE>site_type</CODE> ensemble encapsulates a site type element in Vivado

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export site_type
}

## @brief The <CODE>sites</CODE> ensemble encapsulates the <CODE>site</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::site_type {
    namespace export \
        get_logical_bels \
        get_routing_bels \
        get_site_wires \
        get_site_pins
    namespace ensemble create
}

proc ::tincr::site_type::get_logical_bels { this } {
    return {}
}

proc ::tincr::site_type::get_routing_bels { this } {
    return {}
}

proc ::tincr::site_type::get_site_wires { this } {
    return {}
}

proc ::tincr::site_type::get_site_pins { this } {
    return {}
}
