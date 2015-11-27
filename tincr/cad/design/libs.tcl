## @file libs.tcl
#  @brief Query and modify <CODE>lib</CODE> objects in Vivado.
#
#  The <CODE>libs</CODE> ensemble provides procs that query libraries.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export libs
}

## @brief The <CODE>libs</CODE> ensemble encapsulates the <CODE>lib</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::libs {
	namespace export \
		test \
		test_proc \
		get
	namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>libs</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::libs::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad design libs all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>libs</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::libs::test_proc {proc args} {
	exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design libs "$proc.test"] {*}$args
}

## Queries Vivado's object database for a list of <CODE>lib</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_libs</CODE> command.
proc ::tincr::libs::get { args } {
	return [get_libs {*}$args]
}
