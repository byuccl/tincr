## @file wires.tcl
#  @brief Query <CODE>wire</CODE> objects in Vivado.
#
#  The <CODE>wires</CODE> ensemble provides procs that query a device's wires.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export wires
}

## @brief The <CODE>wires</CODE> ensemble encapsulates the <CODE>wire</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::wires {
	namespace export \
		test \
		get \
		get_info
	namespace ensemble create
}

proc ::tincr::wires::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad device wires all.tcl] {*}$args
}

proc ::tincr::wires::get { args } {
	# TODO Add [get_wires -of_objects [get_tiles [file dirname $wire]] $wire]
	return [get_wires {*}$args]
}

## Get information about a wire that can be obtained from parsing its name.
# @param wire The <CODE>wire</CODE> object.
# @param info The information to get about the wire. Valid values include <CODE>tile</CODE> or <CODE>name</CODE>.
# @return The specified value as a string.
proc ::tincr::wires::get_info { wire {info wire} } {
	if {[regexp {(\w+)/(\w+)} $wire matched tile name]} {
		return [subst $[subst $info]]
	} else {
		error "ERROR: \"$wire\" isn't a valid wire name."
	}
}
