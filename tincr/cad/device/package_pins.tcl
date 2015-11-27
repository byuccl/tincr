## @file package_pins.tcl
#  @brief Query <CODE>package_pin</CODE> objects in Vivado.
#
#  The <CODE>package_pins</CODE> ensemble provides procs that query a device's package pins.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export package_pins
}

## @brief The <CODE>package_pins</CODE> ensemble encapsulates the <CODE>package_pin</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::package_pins {
	namespace export \
		test \
		get
	namespace ensemble create
}

proc ::tincr::package_pins::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad device package_pins all.tcl] {*}$args
}

proc ::tincr::package_pins::get { args } {
	return [get_package_pins {*}$args]
}
