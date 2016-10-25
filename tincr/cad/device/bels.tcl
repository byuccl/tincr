## @file bels.tcl
#  @brief Query <CODE>bel</CODE> objects in Vivado.
#
#  The <CODE>bels</CODE> ensemble provides procs that query a device's BELs.

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export bels
}

## @brief The <CODE>bels</CODE> ensemble encapsulates the <CODE>bel</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::bels {
    namespace export \
        test \
        get \
        get_name \
        get_type \
        unique \
        get_info \
        instance_route_through \
        get_types \
        get_site_types \
        iterate \
        compatible_with_lib_cell \
        compatible_with_cell \
        compatible_with \
        is_lut5 \
        is_lut6 \
        is_lut \
        is_route_through \
        remove_route_through
    namespace ensemble create
}

proc ::tincr::bels::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device bels all.tcl] {*}$args
}

# TODO: "get_bels -of $net" doesn't return the BELs a net travels through via "route-throughs".
# TODO: "get_bels -of $bel_pin" runs for a long time on its first call (populating its cache). Parsing the BEL pin name would return faster until cache is populated (parallelize it).
proc ::tincr::bels::get { args } {
    set regexp 0
    set nocase 0
    set quiet 0
    set verbose 0
    ::tincr::parse_args {types filter of_objects} {regexp nocase quiet verbose} {patterns} {} $args
    
    set arguments [list]
    
    if {[info exists filter]} {
        lappend arguments "-filter" $filter
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
    
    if {[info exists of_objects]} {
        if {[get_property CLASS $of_objects] == "bel_pin"} {
            ::tincr::cache::get array.bel_pin.bel belpin2bel
            return $belpin2bel($of_objects)
        }
        
        lappend arguments "-of_objects" $of_objects
    }
    
    set bels [get_bels {*}$arguments]
    
    if {[info exists types]} {
        ::tincr::cache::get array.bel_type.bels beltype2bels
        if {[llength $types] == 1} {
            set types [list $types]
        }
        
        set bels_of_types {}
        
        foreach type $types {
            ::struct::set add bels_of_types $beltype2bels($type)
        }
        
        set bels [::struct::set intersect $bels $bels_of_types]
    }
    
    return $bels
}

## Get the name of a BEL.
# @param bel The <CODE>bel</CODE> object.
# @return The name of the BEL as a string.
proc ::tincr::bels::get_name { bel } {
    return [get_property NAME $bel]
}

## Get the type of a BEL.
# @param bel The <CODE>bel</CODE> object.
# @return The BEL's type as a string.
proc ::tincr::bels::get_type { bel } {
    return [get_property TYPE $bel]
}

## Get a list of BELs on the device that is unique based on BEL type.
# TODO Remove args processing.
proc ::tincr::bels::unique { args } {
    set per_site_type 0
    ::tincr::parse_args {} {per_site_type} {belType} {} $args
    ::tincr::cache::get array.bel_type.bels beltype2bels
    
    if {[info exists belType]} {
        return [lindex $beltype2bels($belType) 0]
    }
    
    set unique_bels [list]
    if {$per_site_type} {
        foreach site [sites unique] {
            set type_map [dict create]
            
            foreach bel [get_bels -of_objects $site] {
                dict set type_map [get_property TYPE $bel] $bel
            }
            
            lappend unique_bels {*}[dict values $type_map]
        }
    } else {
        foreach {bel_type bels} [array get beltype2bels] {
            lappend unique_bels [lindex $bels 0]
        }
    }
    return $unique_bels
}

## Get information about a BEL that can be found by parsing its name.
# @param bel The <CODE>bel</CODE> object.
# @param info which information to get about the BEL. Valid values include <CODE>site</CODE> or <CODE>name</CODE>.
# @return The specified value as a string.
proc ::tincr::bels::get_info { bel {info bel} } {
    if {[regexp {(\w+)/(\w+)} $bel matched site name]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$bel\" isn't a valid BEL name."
    }
}

# While it is not possible for a user to manually instance a true route-through in Vivado, it is possible to emulate the behavior of a route-through by instancing a BUF cell on the BEL you wish to route the net through.
proc ::tincr::bels::instance_route_through { args } {
    # TODO Implement this in the net ensemble
}

## Get the alternate types of a BEL. Some BELs can change their type without changing the type of the parent site. Vivado does not provide a listing of these alternate types, and the only way to discover them is by placing a cell using the name of the BEL's alternate type instance.
# @param bel The <CODE>bel</CODE> object.
# @return A list of the alternate <CODE>bel</CODE> objects.
proc ::tincr::bels::get_types { bel } {
    # TODO This is a planned feature.
}

## Get the site types of a BEL, including alternate site types. NOTE: This command accesses a cached array that must first be generated. The first time this command is run in a Vivado session, it will take significantly longer than subsequent calls to the command.
# @param bel The <CODE>bel</CODE> object.
# @return A list of site types of the parent <CODE>site</CODE> object that include this BEL.
proc ::tincr::bels::get_site_types { bel } {
    ::tincr::cache::get array.bel.site_types bel2sitetypes
    return $bel2sitetypes($bel)
}

## Iterate over the set of BELs associated with the given object.
# @param var The name of the variable that will represent the <CODE>bel</CODE> object in each iteration.
# @param obj The object that will be queried for its set of <CODE>bel</CODE> objects.
# @param body The script that will executed each iteration.
proc ::tincr::bels::iterate { var obj body } {
    # TODO This is a planned feature
}

proc ::tincr::bels::compatible_with_lib_cell {lib_cell} {
    ::tincr::cache::get array.lib_cell.bels libcell2bels
    return $libcell2bels($lib_cell)
}

proc ::tincr::bels::compatible_with_cell {cell} {
    ::tincr::cache::get array.lib_cell.bels libcell2bels
    return $libcell2bels([get_property REF_NAME $cell])
}

## Get the BELs that the given objects can be placed on. Valid objects include <CODE>lib_cell</CODE>s and <CODE>cell</CODE>s.
# @param objs The list of objects.
# @return A list of <CODE>bel</CODE> objects that one or more of the listed objects can be placed on.
proc ::tincr::bels::compatible_with {objs} {
    set result {}
    if {[llength $objs] == 1} {
        set objs [list $objs]
    }
    
    foreach obj $objs {
        switch [::tincr::get_class $obj] {
            lib_cell {
                ::struct::set add result [compatible_with_lib_cell $obj]
            }
            cell {
                ::struct::set add result [compatible_with_cell $obj]
            }
        }
    }
    
    return $result
}

## A simple proc to tell if a given BEL is a LUT5
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT5, false (0) otherwise.
proc ::tincr::bels::is_lut5 {bel} {
    set bel [get_bels $bel]
    set type [::tincr::get_type $bel]
    if {$type=="LUT5" || $type=="LUT_OR_MEM5"} {
        return 1
    }
    return 0
}

## A simple proc to tell if a given BEL is a LUT6
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT6, false (0) otherwise.
proc ::tincr::bels::is_lut6 {bel} {
    set bel [get_bels $bel]
    set type [::tincr::get_type $bel]
    if {$type=="LUT6" || $type=="LUT_OR_MEM6"} {
        return 1
    }
    return 0
}

## A simple proc to tell if a given BEL is a LUT
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT, false (0) otherwise.
proc ::tincr::bels::is_lut {args} {
    ::tincr::parse_args {} {} {} {bel} $args
    set bel [get_bels -quiet $bel]
    set type [::tincr::get_type $bel]
    if {$type=="LUT6" || $type=="LUT5" || $type=="LUT_OR_MEM6" || $type=="LUT_OR_MEM5"} {
        return 1
    }
    return 0
}

## Is this BEL a route-through?
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if this BEL is being used as a route through, false (0) otherwise.
proc ::tincr::bels::is_route_through {bel} {
    
    # If a BEL is used, it can't be a routethrough
    if { [get_property IS_USED $bel] } {
        return false;
    }
    
    # If its not used, test the CONFIG.EQN string of the bel
    return [regexp {O[5,6]=\(A[1-6]\) ?} [get_property CONFIG.EQN $bel] match]
}

## Remove the route-through (i.e. replace it with a BUF cell)
proc ::tincr::bels::remove_route_through {args} {
    # TODO Is this a good location for this proc?
}
