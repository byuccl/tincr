## @file site.tcl
#  @brief Query <CODE>site</CODE> objects in Vivado.
#
#  The <CODE>site</CODE> ensemble acts as a wrapper class for Vivado's native site type.

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export site
}

## @brief The <CODE>sites</CODE> ensemble encapsulates the <CODE>site</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::site {
    namespace export \
        test1 \
        test2 \
        get_name \
        get_type \
        get_bels \
        get_cells \
        get_tile \
        get_site_pins \
        get_site_pips \
        is_alternate_type \
        has_alternate_types \
        get_alternate_types\
        get_types \
        set_type \
        get_routing_bels
    namespace ensemble create
}

proc ::tincr::site::test1 {} {
    set ::tincr::site::foo "hello"
}

proc ::tincr::site::test2 {} {
    puts $::tincr::site::foo
}

proc ::tincr::site::get_name { this } {
    return [get_property NAME $this]
}

## Get a site's type. This will return the current type of a site instanced by an alternate type.
# @param site The <CODE>site</CODE> object.
# @return The current type of the site as a string.
proc ::tincr::site::get_type { this } {
    return [get_property SITE_TYPE $this]
}

proc ::tincr::site::get_bels { this } {
    return [::get_bels -quiet -of_objects $this]
}

proc ::tincr::site::get_cells { this } {
    return [::get_cells -quiet -of_objects $this]
}

proc ::tincr::site::get_tile { this } {
    return [::get_tiles -quiet -of_objects $this]
}

proc ::tincr::site::get_site_pins { this } {
    if {[is_alternate_type $this]} {
        # TODO Write logic for returning the site_pins of alternate site types
    }
    return [::get_site_pins -quiet -of_objects $this]
}

proc ::tincr::site::get_site_pips { this } {
    return [::get_site_pips -quiet -of_objects $this]
}

proc ::tincr::site::is_alternate_type { this } {
    return [::struct::set contains [get_alternate_types] [get_type $this]]
}

## Determine whether or not a site alternate types.
# @param site The <CODE>site</CODE> object.
# @return True (1) if the site has alternate types, false (0) otherwise.
proc ::tincr::site::has_alternate_types { this } {
    if {[llength [sites get_alternate_types $this]] != 0} {
        return 1
    }
    
    return 0
}

## Get the alternate types of a site.
# @param The <CODE>site</CODE> object.
# @return A Tcl list of the site's alternate types as strings.
proc ::tincr::site::get_alternate_types { this } {
    return [get_property ALTERNATE_SITE_TYPES $this]
}

proc ::tincr::site::get_types { this } {
    ::tincr::cache::get array.site.site_types site2sitetypes
    return $site2sitetypes($this)
}

# TODO Fix the arguments on this one.
## Set one or more sites' type.
# @param sites The <CODE>site</CODE> object or list of <CODE>site</CODE> objects whose type is to be set.
# @param type The site type to set the given site(s) to.
# @return The list of sites whose type has successfully been changed.
proc ::tincr::site::set_type { sites {type ""} } {
    set force 0
    set verbose 0
    set quiet 0
#   ::tincr::parse_args {} {force verbose quiet} {type} {sites} $args
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
proc ::tincr::site::get_routing_bels { this } {
    set muxes {}
    
    foreach site_pip [::get_site_pips -of_object $this] {
        # Format of a site PIP's name: <site>/<routing BEL>:<input BEL pin>
        set mux [lindex [split $site_pip "/:"] 1]
        if {[lsearch $muxes $mux] == -1} {
            lappend muxes $mux
        }
    }
    
    return $muxes
}
