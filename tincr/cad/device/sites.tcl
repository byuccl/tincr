## @file sites.tcl
#  @brief Query <CODE>site</CODE> objects in Vivado.
#
#  The <CODE>sites</CODE> ensemble provides procs that query a device's sites.

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export sites
}

## @brief The <CODE>sites</CODE> ensemble encapsulates the <CODE>site</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::sites {
    namespace export \
        test \
        get \
        get_used \
        iterate \
        unique \
        is_alternate_type \
        has_alternate_types \
        get_alternate_types \
        get_types \
        get_type \
        set_type \
        get_routing_muxes \
        get_info \
        compatible_with \
        get_site_wire_sinks \
        get_route_throughs
    namespace ensemble create
}

proc ::tincr::sites::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device sites all.tcl] {*}$args
}

# TODO: "get_sites -of $net" doesn't return the sites a net travels through via "route-throughs". These may be obtained using "get_sites -quiet -of [get_site_pins -quiet -of [get_nodes -quiet -of $net]]"
proc ::tincr::sites::get { args } {
#    return [get_sites {*}$args]
    
    set regexp 0
    set nocase 0
    set quiet 0
    set verbose 0
    ::tincr::parse_args {type filter range of_objects} {regexp nocase quiet verbose} {patterns} {} $args
    
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
    
    set sites [get_sites {*}$arguments]
    
    if {[info exists type]} {
        if {[lsearch [list_property_value -class site SITE_TYPE] $type] == -1} {
            error "ERROR: \"$type\" is not a valid site type."
        }
        
        ::tincr::cache::get array.site_type.sites sitetype2sites
        set sites [::struct::set intersect $sites $sitetype2sites($type)]
    }
    
    return $sites
}

# TODO Figure out at what point get_used is slower than "get_sites -filter..."
#      and incorporate it into "sites get" (use whichever method is faster)

## Get a list of the sites that are used in the current design.
#  This finds used sites by iterating over the design's cells. For small 
#  designs on large devices, this runs faster than the equivalent Vivado
#  command <CODE>get_sites -filter IS_USED</CODE>.
#  However, this command will run more slowly than the Vivado command on dense,
#  complex designs.
proc ::tincr::sites::get_used {} {
#    set sites {}
#    foreach cell [get_cells -hierarchical] {
#        set site [get_sites -quiet -of_object $cell]
#        if {$site != ""} {
#            dict set sites $site 1
#        }
#    }
#    
#    return [dict keys $sites]
    return [get_sites -filter IS_USED]
}

## Iterate through each <CODE>site</CODE> object on the device and each of its possible type configurations, while executing some piece of code across all of these combinations.
# TODO Fix the args to this proc.
proc ::tincr::sites::iterate { args } {
    set of_type ""
    set all 0
    ::tincr::parse_args {of_type} {all} {} {siteVar body} $args
    upvar 1 $siteVar site
    
    ::tincr::cache::get list.site.site_type sitesitetypepairs
    
    if {$all} {
        set prev_site ""
        set prev_type ""
        foreach {site type} $sitesitetypepairs {
            # Is there a previously visited site that needs restoration?
            if {$prev_site != "" && $prev_site != $site} {
                reset_property MANUAL_ROUTING $prev_site
                if {$prev_type == ""} {
                    set_property MANUAL_ROUTING [get_property SITE_TYPE $prev_site] $prev_site
                    reset_property MANUAL_ROUTING $prev_site
                } else {
                    set_property MANUAL_ROUTING $prev_type $prev_site
                }
                set prev_site ""
            }
            
            # The only sites that may need to be restored are those with alternate types
            if {[get_property ALTERNATE_SITE_TYPES $site] != ""} {
                # Skip sites that have cells placed
                set cells [get_cells -quiet -of_objects $site]
                if {[llength $cells] > 0} {
                    # Here would be the place to add a -force option (see set_type)
                    continue
                }
                
                # Is this the first time visiting this site?
                if {$prev_site != $site} {
                    set prev_type [get_property MANUAL_ROUTING $site]
                    set prev_site $site
                }
                
                # Set the site to its alternate type
                reset_property MANUAL_ROUTING $site
                set_property MANUAL_ROUTING $type $site
            }
            
            # Run the user's script
            uplevel 1 $body
        }
        if {$prev_site != ""} {
            reset_property MANUAL_ROUTING $prev_site
            if {$prev_type == ""} {
                set_property MANUAL_ROUTING [get_property SITE_TYPE $prev_site] $prev_site
                reset_property MANUAL_ROUTING $prev_site
            } else {
                set_property MANUAL_ROUTING $prev_type $prev_site
            }
        }
    } else {
        foreach site [get_sites] {
            uplevel 1 $body
        }
    }
}

## Creates a dictionary that maps a site type to a physical site location 
#   on the current device. This function chooses default site locations 
#   over alternate site locations, and chooses a different site location for alternate 
#   types if possible. If <code>include_alternate_only_sites</code> is specified
#   then the site types that are only alternate types are also returned. 
#
# @returns If <code>include_alternate_only_sites</code> == 0: <br>
#           A dictionary that maps a site type to a site location <br>
# <br>
#          If <code>include_alternate_only_sites</code> == 1: <br>
#           A list with two elements: <br>
#           (1) The first element is a dictionary that maps a site type to a site location <br>
#           (2) A set of site types that are only alternate site types <br>
proc ::tincr::sites::unique { {include_alternate_only_sites 0} } {
    set default_sites [dict create]
    set alternates [dict create]
    set global_site_map [dict create]
    set alternate_index [dict create]
    
    foreach site [get_sites] {
        
        set default_site_type [get_property SITE_TYPE $site]
        
        dict lappend global_site_map $default_site_type $site
        
        # add to the map of default site types if we haven't encountered this site type before
        if {![dict exists $default_sites $default_site_type]} {
            dict set default_sites $default_site_type $site
        }

        # add all alternate site types to the alternate site map
        foreach alternate_type [get_property ALTERNATE_SITE_TYPES $site] {
            if {![dict exists $alternates $alternate_type]} {
                dict set alternates $alternate_type $default_site_type
                dict set alternate_index $default_site_type 1 
            }
        }
    }
    
    set alternate_only_site_set [list]
    # If a site in the alternate dictionary is not already in the default dictionary, add it with a unique site
    # NOTE: IOB sites cause Vivado to crash when you set alternate site types that are IOBs
    #   so, unfortunately, we have to ignore these until the bug is fixed. This is generally not an 
    #   issue because all IOB sites show up as non-default types. 
    dict for {alternate_type site} $alternates {
        if { ![dict exists $default_sites $alternate_type] && ![string match {*IOB*} $alternate_type] } {
            
            set index [dict get $alternate_index $site]
            set site_list [dict get $global_site_map $site]
            
            # grab a unique site for the alternate site so we don't mess up the placement on default site types
            dict set default_sites $alternate_type [lindex $site_list $index]
            ::struct::set add alternate_only_site_set $alternate_type
            
            dict incr alternate_index $site
        }
    }
    
    if {$include_alternate_only_sites} {
        return [list $default_sites $alternate_only_site_set]
    } else {
        return $default_sites
        
    }
}

## Determine whether the site type of a site is an alternate site type.
# @param site The <CODE>site</CODE> object.
# @param type The site type as a string. Defaults to <CODE>site</CODE>'s current type.
# @return True (1) if the given site type is one of <CODE>site</CODE>'s alternate types, false (0) otherwise.
proc ::tincr::sites::is_alternate_type { site {type ""} } {
    if {$type == ""} {
        set type [get_property SITE_TYPE $site]
    }
    
    return [expr [lsearch [get_property ALTERNATE_SITE_TYPES $site] $type] != -1]
}

## Determine whether or not a site alternate types.
# @param site The <CODE>site</CODE> object.
# @return True (1) if the site has alternate types, false (0) otherwise.
proc ::tincr::sites::has_alternate_types { site } {
    if {[llength $site] > 1} {
        error "ERROR Expected one site object."
    }
    
    if {[llength [get_alternate_types $site]] != 0} {
        return 1
    }
    
    return 0
}

## Get the alternate types of a site.
# @param The <CODE>site</CODE> object.
# @return A Tcl list of the site's alternate types as strings.
proc ::tincr::sites::get_alternate_types { site } {
    return [get_property ALTERNATE_SITE_TYPES $site]
}

#TODO Combine this proc with the previous one.
## Get a list of all site types (including alternate only types) in the current device or for a set of <CODE>site</CODE> objects. This returned list will be a subset of the list of all possible site types returned by the Vivado command: list_property_value SITE_TYPE -class site.
# @param sites The Tcl list of <CODE>site</CODE> objects as a set. If empty, all sites in the device will be used.
# @return A sorted list of all site types present in the sites provided or the current device. This is presented as a list of strings.
proc ::tincr::sites::get_types { {sites ""} } {
    set results [list]
    
    if {$sites == ""} {
        set sites [get_sites]
    }
    if {[llength $sites] == 1} {
        set sites [list $sites]
    }
    foreach site $sites {
        set results [struct::set union $results [get_property SITE_TYPE $site] [get_property ALTERNATE_SITE_TYPES $site]]
    }

    return [lsort $results]
}

## Get a site's type. This will return the current type of a site instanced by an alternate type.
# @param site The <CODE>site</CODE> object.
# @return The current type of the site as a string.
proc ::tincr::sites::get_type { site } {
    return [get_property SITE_TYPE $site]
}

# TODO Fix the arguments on this one.
## Set one or more sites' type.
# @param sites The <CODE>site</CODE> object or list of <CODE>site</CODE> objects whose type is to be set.
# @param type The site type to set the given site(s) to.
# @return The list of sites whose type has successfully been changed.
proc ::tincr::sites::set_type { sites {type ""} } {
    set force 0
    set verbose 0
    set quiet 0
#    ::tincr::parse_args {} {force verbose quiet} {type} {sites} $args
    if {[llength $sites] == 1} {
        set sites [list $sites]
    }
    ::tincr::cache::get array.site_type.sites sitetype2sites
    
    if {$type != ""} {
        set diff [::struct::set difference $sites $sitetype2sites($type)]
        
        if {[llength $diff] > 0} {
            if {$verbose} {
                puts "WARNING: The following sites are incompatible with type $type and will remain unchanged:"
                puts $diff
            } elseif {!$quiet} {
                puts "WARNING: [llength $diff] sites are incompatible with type $type and will remain unchanged."
            }
        }
        set sites [::struct::set intersect $sites $sitetype2sites($type)]
        foreach site $sites {
            if {[get_property MANUAL_ROUTING $site] != $type} {
                set cells [get_cells -quiet -of_objects $site]
                
                if {[llength $cells] > 0} {
                    if {$force} {
                        unplace_cell $cells
                    } elseif {!$quiet} {
                        puts "WARNING: Site \"$site\" has a fixed type (cells are placed here) and will be skipped. To change this site's type anyway, use the -force option. (NOTE: all cells will be unplaced)"
                        continue
                    }
                }
                
                reset_property MANUAL_ROUTING $site
                set_property MANUAL_ROUTING $type $site
            }
        }
    } else {
        foreach site $sites {
            if {[get_property ALTERNATE_SITE_TYPES $site] != ""} {
                reset_property MANUAL_ROUTING $site
                set_property MANUAL_ROUTING [get_property SITE_TYPE $site] $site
                reset_property MANUAL_ROUTING $site
            }
        }
    }
    
    return $sites
}

# TODO Planned feature: create a "routing mux" Tcl class using this and similar methods to populate it.
## Get a list of the routing bels (site muxes) of a site. Unfortunately, site muxes cannot be returned as first-class Tcl objects. No Vivado Tcl command can get handles to the mux objects. In Vivado 2013.2 and earlier, the command internal::get_rbels returns routing bels of a site. The only way to get handles to the routing bels in later versions of Vivado seems to be by clicking on them in the GUI and calling get_selected_objects.
# @param site The <CODE>site</CODE> object.
# @return A list of all the muxes in the specified site, including routing bels, logical bel muxes, and LUTs.
proc ::tincr::sites::get_routing_muxes { site } {
    set muxes {}
    
    foreach site_pip [get_site_pips -of_object $site ${site}/*:*] {
        regexp {\w+/(\w+):\w+} $site_pip matched mux
        
        if {$matched != "" && [lsearch $muxes $mux] == -1} {
            lappend muxes $mux
        }
    }
    
    return $muxes
}

## Get information about a <CODE>site</CODE> object that can be found by parsing its name.
# @param site The <CODE>site</CODE> object.
# @param info What information to get about the site. Valid values include "tile", "x", or "y".
# @return The requested information about the site.
proc ::tincr::sites::get_info { site {info site} } {
    if {[regexp {([A-Z0-9]+)_X([0-9]+)Y([0-9]+)} $site matched type x y]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR \"$site\" isn't a valid site name."
    }
}

# TODO Planned feature: Obtain a list of sites that are compatible with a given object.
## Get the sites that the given objects can be placed on. Valid objects include <CODE>lib_cell</CODE> and <CODE>cell</CODE> objects.
# @param objs The list of objects.
# @return A list of <CODE>site</CODE> objects that one or more of the listed objects can be placed on.
proc ::tincr::sites::compatible_with {objs} {
#    set result {}
#    if {[llength $objs] == 1} {
#        set objs [list $objs]
#    }
#    
#    foreach obj $objs {
#        switch [::tincr::get_class $obj] {
#            lib_cell {
#                ::tincr::cache::get array.lib_cell.bel_types libcell2beltypes
#                if {[info exists libcell2beltypes($obj)]} {
#                    ::struct::set add result [get -type $libcell2beltypes($obj)]
#                }
#            }
#            cell {
#                ::struct::set add result [compatible_with [get_lib_cells -of_objects $obj]]
#            }
#        }
#    }
#    
#    return $result
}

## Get the sink objects of a source object within a site. This command allows the user to obtain routing information within a site. Because this information cannot be generated using Vivado, a primitive definition file is required.
# @param source The source object. Valid objects include <CODE>bel_pin</CODE>s, <CODE>site_pin</CODE>s, or <CODE>site_pip</CODE>s.
# @return A list of <CODE>bel_pin</CODE>, <CODE>site_pin</CODE>, and/or <CODE>site_pip</CODE> objects that are sinks of the site wire sourced by <CODE>source</CODE>.
proc ::tincr::sites::get_site_wire_sinks {source} {
    set result [list]
    set site [get_sites -quiet -of_objects $source]
    if {$site != ""} {
        set primitive_type [get_property SITE_TYPE [get_sites -quiet -of_objects $source]]
        set src_bel ""
        set src_pin ""
        
        switch [::tincr::get_class $source] {
            site_pin {
                set src_bel [::tincr::site_pins get_info $source name]
                set src_pin [::tincr::site_pins get_info $source name]
            }
            bel_pin {
                set src_bel [::tincr::bel_pins get_info $source bel]
                set src_pin [::tincr::bel_pins get_info $source name]
            }
            site_pip {
                set src_bel [::tincr::site_pips get_info $source bel]
                set src_pin [::tincr::site_pips get_info $source pin]
            }
            default {
                error "ERROR: Invalid object. Must be either BEL pin or site pin."
            }
        }
        
        ::tincr::cache::get dict.site_type.src_bel.src_pin.snk_bel.snk_pins connections
        if {[dict exists $connections $primitive_type $src_bel $src_pin]} {
            dict for {snk_bel snk_pin} [dict get $connections $primitive_type $src_bel $src_pin] {
                # TODO There's a flaw with the following line. Some site PIPs have the same snk_bel and snk_pin names as BEL pins (i.e. BEL route-throughs), and will be returned by this function.
                set result [struct::set union $result [get_site_pins -quiet -of_object $site "[::tincr::get_name $site][get_hierarchy_separator]${snk_bel}"] [get_site_pips -quiet -of_object $site "[::tincr::get_name $site][get_hierarchy_separator]${snk_bel}:${snk_pin}"] [get_bel_pins -quiet -of_object $site "[::tincr::get_name $site][get_hierarchy_separator]${snk_bel}[get_hierarchy_separator]${snk_pin}"]]
            }
        }
    }
    
    return $result
}

# TODO Planned feature: Get the route-throughs in a site.
proc ::tincr::sites::get_route_throughs {source} {
    
}
