## @file pblocks.tcl
#  @brief Query and modify <CODE>pblock</CODE> objects in Vivado.
#
#  The <CODE>pblocks</CODE> ensemble provides procs that query or modify partition blocks in a design.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export pblocks
}

## @brief The <CODE>pblocks</CODE> ensemble encapsulates the <CODE>pblock</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::pblocks {
	namespace export \
		test \
		get
	namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>pblocks</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::pblocks::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad design pblocks all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>pblocks</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::pblocks::test_proc {proc args} {
	exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design pblocks "$proc.test"] {*}$args
}

proc ::tincr::pblocks::get { args } {
	return [get_pblocks {*}$args]
}
