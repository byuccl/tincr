## @file clocks.tcl
#  @brief Query and modify <CODE>clock</CODE> objects in Vivado.
#
#  The <CODE>clocks</CODE> ensemble provides procs that get information about or modify a design's clocks in Vivado.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export clocks
}

## @brief The <CODE>clocks</CODE> ensemble encapsulates the <CODE>clock</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::clocks {
	namespace export \
		test \
		test_proc \
		get
#		invert
	namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>clocks</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::clocks::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad design clocks all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>clocks</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::clocks::test_proc {proc args} {
	exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design clocks "$proc.test"] {*}$args
}

## Queries Vivado's object database for a list of <CODE>clock</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_clocks</CODE> command.
proc ::tincr::clocks::get { args } {
	return [get_clocks {*}$args]
}

#proc ::tincr::clocks::invert { clocks } {
#	if {[llength $clocks] == 1} {
#		set clocks [list $clocks]
#	}
#	
#	set_property 
#}
