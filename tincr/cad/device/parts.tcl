## @file parts.tcl
#  @brief Query <CODE>part</CODE> objects in Vivado.
#
#  The <CODE>parts</CODE> ensemble provides procs that query the various parts available in Vivado.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export parts
}

## @brief The <CODE>parts</CODE> ensemble encapsulates the <CODE>part</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::parts {
	namespace export \
		test \
		get
	namespace ensemble create
}

proc ::tincr::parts::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad device parts all.tcl] {*}$args
}

proc ::tincr::parts::get { args } {
	return [get_parts {*}$args]
}
