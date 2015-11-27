## @file lib_pins.tcl
#  @brief Query and modify <CODE>lib_pin</CODE> objects in Vivado.
#
#  The <CODE>lib_pins</CODE> ensemble provides procs that query library pins.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export lib_pins
}

## @brief The <CODE>lib_pins</CODE> ensemble encapsulates the <CODE>lib_pin</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::lib_pins {
	namespace export \
		test \
		test_proc \
		get
	namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>lib_pins</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::lib_pins::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad design lib_pins all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>lib_pins</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::lib_pins::test_proc {proc args} {
	exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design lib_pins "$proc.test"] {*}$args
}

## Queries Vivado's object database for a list of <CODE>lib_pin</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_lib_pins</CODE> command.
proc ::tincr::lib_pins::get { args } {
	return [get_lib_pins {*}$args]
}
