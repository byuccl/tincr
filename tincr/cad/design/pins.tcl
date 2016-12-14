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
        new \
        delete \
        rename \
        get \
        info \
        remove \
        connect_net \
        disconnect_net \
        get_pin_type
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

## Create a new pin.
# @param name The name of the new pin.
# @param direction The direction of the new pin. Valid values are IN, OUT, and INOUT.
# @param cell The name of the cell to add this pin to, if one.
# @return The newly created <CODE>pin</CODE> object.
proc ::tincr::pins::new { name direction { cell "" } } {
    if {$cell != ""} {
        set name [join [list $cell $name] [get_hierarchy_separator]]
    }
    
    return [create_pin -direction $direction $name]
}

## Delete a pin.
# @param name The pin to delete.
proc ::tincr::pins::delete { pin } {
    remove_pin -quiet $pin
}

## Rename a pin.
# @param pin The pin to rename.
# @param name The new name.
proc ::tincr::pins::rename { pin name } {
    rename_pin -to $name $pin
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

## Disconnect a pin from a net.
# @param pin The <CODE>pin</CODE> object.
# @param net The <CODE>net</CODE> object.
proc ::tincr::pins::disconnect_net { pin net } {
    disconnect_net -quiet -net $net $pin
}

## Gets the type of the pin according to Vivado. DATA is the
#   default pin type where no other pin type is specified. Other valid pin types
#   include CLEAR, CLOCK, ENABLE, PRESET, RESET, SET, SETRESET, AND WRITE_ENABLE
#   TODO: on each new release of Vivado, verify this function is still correct.
#           This has to be manually verified.
#
# @param pin Cell pin
# @return The type of cell pin
proc ::tincr::pins::get_pin_type { pin } {

    if { [get_property IS_CLEAR $pin] } {
        return "CLEAR"
    } elseif { [get_property IS_CLOCK $pin] } {
        return "CLOCK"
    } elseif { [get_property IS_ENABLE $pin] } {
        return "ENABLE"
    } elseif { [get_property IS_PRESET $pin] } {
        return "PRESET"
    } elseif { [get_property IS_RESET $pin] } {
        return "RESET"
    } elseif { [get_property IS_SET $pin] } {
        return "SET"
    } elseif { [get_property IS_SETRESET $pin] } {
        return "SETRESET"
    } elseif { [get_property IS_WRITE_ENABLE $pin] } {
        return "WRITE_ENABLE"
    } else {
        return "DATA"
    }
}
