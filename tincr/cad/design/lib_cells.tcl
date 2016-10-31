## @file lib_cells.tcl
#  @brief Query and modify <CODE>lib_cell</CODE> objects in Vivado.
#
#  The <CODE>lib_cells</CODE> ensemble provides procs that query library cells.

package provide tincr.cad.design 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export lib_cells
}

## @brief The <CODE>lib_cells</CODE> ensemble encapsulates the <CODE>lib_cell</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::lib_cells {
    namespace export \
        test \
        test_proc \
        get \
        compatible_with \
        is_lut \
        get_supported_libcells \
        get_supported_leaf_libcells
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>lib_cells</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::lib_cells::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design lib_cells all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>lib_cells</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::lib_cells::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design lib_cells "$proc.test"] {*}$args
}

## Queries Vivado's object database for a list of <CODE>lib_cell</CODE> objects that fit the given criteria. This is mostly a wrapper function for Vivado's <CODE>get_lib_cells</CODE> command, though it does add additional features (such as getting the library cells of an architecture).
proc ::tincr::lib_cells::get { args } {
    set regexp 0
    set nocase 0
    set quiet 0
    set verbose 0
    ::tincr::parse_args {architecture filter range of_objects} {regexp nocase quiet verbose} {patterns} {} $args
    
    set arguments [list]
    
    if {[info exists filter]} {
        lappend arguments "-filter" $filter
    }
    if {[info exists range]} {
        lappend arguments "-range" $range
    }
    if {[info exists of_objects]} {
        lappend arguments "-of_objects" $of_objects
    }
    if {$regexp} {
        lappend arguments "-regexp"
    }
    if {$nocase} {
        lappend arguments "-nocase"
    }
    if {$quiet} {
        lappend arguments "-quiet"
    }
    if {$verbose} {
        lappend arguments "-verbose"
    }
    if {[info exists patterns]} {
        lappend arguments $patterns
    }
    
    set lib_cells [get_lib_cells {*}$arguments]
    
    # Deprecated: get_lib_cells used to include lib_cells that were unsupported by the target part, so we would have to filter by architecture, Now, get_lib_cells only returns lib_cells for the target part of the current design.
    if {[info exists architecture]} {
        set lib_cells [::struct::set intersect $lib_cells [get_lib_cells -regexp -filter "SUPPORTED_ARCHITECTURES=~\"ALL|\(\(^|\(.+ \)\)$architecture\(\( .+\)|\$)\)\""]]
    }
    
    return $lib_cells
}

## Get the library cells that are compatible for placement on or within the given objects.
# @param objs The object or list of objects. Legal objects include <CODE>bel</CODE>, <CODE>site</CODE>, and <CODE>tile</CODE> objects.
# @return A list of library cells that may be placed on or within the given object(s).
proc ::tincr::lib_cells::compatible_with {objs} {
    ::set result {}
    if {[llength $objs] == 1} {
        set objs [list $objs]
    }
    
    foreach obj $objs {
        switch [::tincr::get_class $obj] {
            tile {
                foreach site [get_sites -of_object $obj] {
                    ::struct::set add result [compatible_with $site]
                }
            }
            site {
                foreach bel [get_bels -of_objects $obj] {
                    ::struct::set add result [compatible_with $bel]
                }
            }
            bel {
                ::tincr::cache::get array.bel_type.lib_cells beltype2libcells
                if {[info exists beltype2libcells([::tincr::get_type $obj])]} {
                    ::struct::set add result $beltype2libcells([::tincr::get_type $obj])
                }
            }
        }
    }
    
    return $result
}

## Is this library cell a LUT?
# @param lib_cell The library cell to test.
# @return True (1) if <CODE>lib_cell</CODE> is a LUT, false (0) otherwise.
proc ::tincr::lib_cells::is_lut { lib_cell } {
    if {[get_property PRIMITIVE_GROUP $lib_cell] == "LUT"} {
        return 1
    }
    
    return 0
}

## Creates a list of all supported cells in the current device. Cells are marked
#   as supported if, when instantiated, the reference name of the cell instance matches the name
#   of the library cell. Macro cells are included.
#   TODO: update this 
#
# @return A list of supported cells.
proc ::tincr::get_supported_libcells { } {
    set lib_cells [get_lib_cells]
    set supported_cells [list]

    foreach lbc $lib_cells {
        set c [create_cell -reference $lbc tmp -quiet]

        if {[get_property REF_NAME $c] == $lbc} {
            lappend supported_cells $lbc
        }
        remove_cell $c
    }

    return $supported_cells
}

## Creates a list of all supported leaf cells in the current device. Leaf cells are marked
#   as supported if, when instantiated, the reference name of the cell instance matches the name
#   of the library cell. Macro cells are excluded.  
#
# @return A list of supported leaf cells according to criteria above.
proc ::tincr::get_supported_leaf_libcells { } {
    set lib_cells [get_lib_cells]
    set supported_cells [list]
    set i 0

    foreach lbc $lib_cells {
        set c [create_cell -reference $lbc "cell_$i" -quiet]

        if {[get_property REF_NAME $c] == $lbc && [get_property PRIMITIVE_LEVEL $c] == "LEAF"} {
            lappend supported_cells $lbc
        } else {
            remove_cell [get_cells cell_$i]
        }
        incr i
    }

    return $supported_cells
}
