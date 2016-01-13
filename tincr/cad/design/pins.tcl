## @file pins.tcl
#  @brief Query and modify <CODE>pin</CODE> objects in Vivado.
#
#  The <CODE>pins</CODE> ensemble provides procs that query or modify a design's pins.
#

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export pins
}

## @brief The <CODE>pins</CODE> ensemble encapsulates the <CODE>pin</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::pins {
    namespace export \
        test \
        get \
        info \
        remove \
        connect_net
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>pins</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::pins::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design pins all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>pins</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::pins::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design pins "$proc.test"] {*}$args
}

proc ::tincr::pins::get { args } {
    return [get_pins {*}$args]
}

proc ::tincr::pins::info { pin {info name} } {
    # Summary:
    # Get information about a pin that can be found by parsing its name.

    # Argument Usage:
    # pin : the pin object or pin name to query
    # [info = name] : only the name can be found from a pin name

    # Return Value:
    # the requested information

    # Categories: xilinxtclstore, byu, tincr, device

    # Notes:
    # Since there isn't any information in a pin's name, this proc doesn't do
    # a whole lot. This procedure returns the same result [subst $pin].

    if {[regexp {[a-zA-Z0-9_/\[\]\.-]+/([a-zA-Z0-9_/\[\]]+)} $pin matched name]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$pin\" isn't a valid pin name."
    }
}

## Remove a pin from a cell.
# @param pin The pin to remove.
# @return True (1) if successful, false (0) otherwise.
proc ::tincr::pins::remove { pin } {
    # TODO Add return statement (i.e. catch Vivado DNE error)
    remove_pin $pin
}

## Connect a pin to a net.
# @param pin The <CODE>pin</CODE> object.
# @param net The <CODE>net</CODE> object.
proc ::tincr::pins::connect_net { pin net } {
    connect_net -quiet -hierarchical -net $net $pin
}
