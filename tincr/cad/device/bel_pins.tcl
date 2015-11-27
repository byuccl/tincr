## @file bel_pins.tcl
#  @brief Query <CODE>bel_pin</CODE> objects in Vivado.
#
#  The <CODE>bel_pins</CODE> ensemble provides procs that query a device's BEL pins.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export bel_pins
}

## @brief The <CODE>bel_pins</CODE> ensemble encapsulates the <CODE>bel_pin</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::bel_pins {
	namespace export \
		test \
		get \
		get_info
	namespace ensemble create
}

proc ::tincr::bel_pins::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad device bel_pins all.tcl] {*}$args
}

proc ::tincr::bel_pins::get { args } {
	return [get_bel_pins {*}$args]
}

proc ::tincr::bel_pins::get_info { bel_pin {info bel_pin} } {
	# Summary:
	# Get information about a bel_pin that can be found by parsing its name.

	# Argument Usage:
	# bel_pin : the bel_pin object or bel_pin name to query
	# info : which information to get about bel_pin — valid values: site, bel, or name

	# Return Value:
	# the requested information

	# Categories: xilinxtclstore, byu, tincr, device

	if {[regexp {(\w+)/(\w+)/(\w+)} $bel_pin matched site bel name]} {
		return [subst $[subst $info]]
	} else {
		error "ERROR: \"$bel_pin\" isn't a valid BEL pin name."
	}
}
