## @file bel_type.tcl
#  @brief Query <CODE>bel</CODE> objects in Vivado.
#
#  The <CODE>bel</CODE> ensemble acts as a wrapper class for Vivado's native bel type.

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export bel_type
}

## @brief The <CODE>bels</CODE> ensemble encapsulates the <CODE>bel</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::bel_type {
    namespace export \
        get_name \
        get_type \
        get_bels
    namespace ensemble create
}

## Get the name of a BEL.
# @param this The <CODE>bel</CODE> object.
# @return The name of the BEL as a string.
proc ::tincr::bel_type::get_name { this } {
    return $this
}

## Get the type of a BEL.
# @param bel The <CODE>bel</CODE> object.
# @return The BEL's type as a string.
proc ::tincr::bel_type::get_type { this } {
    return "bel_type"
}

proc ::tincr::bel_type::get_bels { this } {
    
}
