## @file macros.tcl
#  @brief Query and modify <CODE>macro</CODE> objects in Vivado.
#
#  The <CODE>macros</CODE> ensemble provides procs that query libraries.

package provide tincr.cad.design 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export macros
}

## @brief The <CODE>macros</CODE> ensemble encapsulates the <CODE>macro</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::macros {
    namespace export \
        test \
        test_proc \
        new \
        delete \
        add_cell \
        get
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>macros</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::macros::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design macros all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>macros</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::macros::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design macros "$proc.test"] {*}$args
}

## Create a new macro.
# @param name The name of the new macro.
# @return The new <CODE>macro</CODE> object.
proc ::tincr::macros::new { name } {
    create_macro $name
    return [get_macro $name]
}

## Delete a macro.
# @param The macro to delete.
proc ::tincr::macros::delete { macro } {
    delete_macros -quiet $macro
}

## Add a cell to the macro.
# @param macro The macro to update.
# @param cell The cell to add.
# @param rloc The relative location.
proc ::tincr::macros::add_cell { macro cell rloc } {
    update_macro $macro [list $cell $rloc]
}

## Queries Vivado's object database for a list of <CODE>macro</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_macros</CODE> command.
proc ::tincr::macros::get { args } {
    return [get_macros {*}$args]
}
