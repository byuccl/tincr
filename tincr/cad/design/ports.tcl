## @file ports.tcl
#  @brief Query and modify <CODE>port</CODE> objects in Vivado.
#
#  The <CODE>ports</CODE> ensemble provides procs that query or modify a design's ports.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export ports
}

## @brief The <CODE>ports</CODE> ensemble encapsulates the <CODE>port</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::ports {
    namespace export \
        test \
        new \
        delete \
        rename \
        get \
        connect_net \
        disconnect_net
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>ports</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::ports::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design ports all.tcl] {*}$args
}

## Create a new port.
# @param name The name of the new port.
# @param direction The direction of the new port. Valid values are IN, OUT, and INOUT.
# $return The newly created <CODE>port</CODE> object.
proc ::tincr::ports::new { name  direction } {
    return [create_port -direction $direction $name]
}

## Delete a port.
# @param name The name of the port to delete.
proc ::tincr::ports::delete { port } {
     remove_port -quiet $port
}

## Rename a port.
# @param port The port to rename.
# @param name The new name.
proc ::tincr::ports::rename { port name } {
    rename_port -to $name $port
}

## Executes all unit tests for a particular proc in the <CODE>ports</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::ports::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design ports "$proc.test"] {*}$args
}

proc ::tincr::ports::get { args } {
    return [get_ports {*}$args]
}

## Connect a port to a net.
# @param port The <CODE>port</CODE> object.
# @param net The <CODE>net</CODE> object.
proc ::tincr::ports::connect_net { port net } {
    connect_net -quiet -hierarchical -net $net $port
}

## Disconnect a port from a net.
# @param port The <CODE>port</CODE> object.
# @param net The <CODE>net</CODE> object.
proc ::tincr::ports::disconnect_net { port net } {
    disconnect_net -quiet -net $net $port
}
