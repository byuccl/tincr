## @file designs.tcl
#  @brief Procedures for operating on an entire design and its objects.
#
#  The <CODE>designs</CODE> ensemble provides procs that query and manipulate all of the objects in a design.

package provide tincr.cad.design 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export designs
}

## @brief The <CODE>designs</CODE> ensemble encapsulates the <CODE>design</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::designs {
    namespace export \
        test \
        test_proc \
        new \
        get \
        summary \
        clear \
        diff \
        get_route_throughs \
		get_routed_tilelength \
		get_critical_delay \
        edif \
        get_buses \
        get_design_buses \
        remove_route_throughs
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>designs</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::designs::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design designs all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>designs</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::designs::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design designs "$proc.test"] {*}$args
}

## Create a new design.
# @param name The name of the new design.
# @param part The FPGA part the new design will target.
# @return The newly created <CODE>design</CODE> object.
proc ::tincr::designs::new { name { part xc7k70tfbg484 } } {
    return [link_design -part $part -name $name]
}

## Queries Vivado's object database for a list of <CODE>design</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_designs</CODE> command.
proc ::tincr::designs::get { args } {
    return [get_designs {*}$args]
}

## Return a dictionary that contains a summary of the current design.
#  ::tincr::designs diff uses this procedure to compare designs.
proc ::tincr::designs::summary {} {
    #TODO Do we still need this summary command?
    
    set net_properties {ROUTE}
    set cell_properties {BEL LOC TYPE}
    set port_properties {DIRECTION IOSTANDARD LOC PACKAGE_PIN}
    parse_options $args
        
    set design {}
    
    foreach net [get_nets -quiet] {
        foreach property $net_properties {
            dict set design nets $net $property [get_property -quiet $property $net]
        }
        dict set design nets $net SOURCE [get_pins -quiet -of_object $net -filter DIRECTION==OUT]
        dict set design nets $net SINKS [get_pins -quiet -of_object $net -filter DIRECTION!=OUT]
    }

    foreach cell [get_cells -quiet] {
        foreach property $cell_properties {
            dict set design cells $cell $property [get_property -quiet $property $cell]
        }
    }
    
    foreach port [get_ports -quiet] {
        foreach property $port_properties {
            dict set design ports $port $property [get_property -quiet $property $port]
        }
    }
    return $design
}

## Delete all of the cells, nets, and ports in a design. This is faster than calling <code>close_project</code> and reopening a design.
proc ::tincr::designs::clear {} {
    remove_cell -quiet [get_cells -quiet]
    remove_net -quiet [get_nets -quiet]
    remove_port -quiet [get_ports -quiet]
}

## Reports the differences between two designs. This includes differences in the netlist, placement, and routing, as well as their relevant attributes.
# @param design1 The first design to compare.
# @param design2 The second design to compare. If this parameter is omitted or empty, the current design will be used.
# @param filename The file that the results will be written to. If this parameter is omitted or empty, <CODE>stdout</CODE> will be used.
proc ::tincr::designs::diff { design1 {design2 ""} {filename ""} } {
#    ::tincr::parse_args {} {} {checkpoint1} {checkpoint2} $args
    
    set SKIP_CELL_PROPERTIES [list FILE_NAME LINE_NUMBER LOCK_PINS]
    set SKIP_NET_PROPERTIES [list FILE_NAME LINE_NUMBER ROUTE BUS_NAME BUS_START BUS_STOP BUS_WIDTH]
    
    set diff stdout
    if {$filename != ""} {
        set diff [open $filename w]
    }
    
    set project2 [current_project]
    if {$design2 != ""} {
        open_checkpoint -quiet $design2
        set project2 [current_project]
    }
    
    open_checkpoint -quiet $design1
    set project1 [current_project]
    
    current_project $project1
    set cell_names1 {}
    foreach cell [get_cells -hierarchical] {
        lappend cell_names1 [get_property NAME $cell]
    }
    set net_names1 {}
    foreach net [get_nets -hierarchical] {
        lappend net_names1 [get_property NAME $net]
    }
    set port_names1 {}
    foreach port [get_ports] {
        lappend port_names1 [get_property NAME $port]
    }
    set design_props1 [dict create]
    set design1 [lindex [get_designs] 0]
    foreach property [list_property $design1] {
        dict set design_props1 $property [get_property -quiet $property $design1]
    }
    
    current_project $project2
    set cell_names2 {}
    foreach cell [get_cells -hierarchical] {
        lappend cell_names2 [get_property NAME $cell]
    }
    set net_names2 {}
    foreach net [get_nets -hierarchical] {
        lappend net_names2 [get_property NAME $net]
    }
    set port_names2 {}
    foreach port [get_ports] {
        lappend port_names2 [get_property NAME $port]
    }
    set design_props2 [dict create]
    set design2 [lindex [get_designs] 0]
    foreach property [list_property $design2] {
        dict set design_props2 $property [get_property -quiet $property $design2]
    }
    
    set diff_cell_names12 [struct::set difference $cell_names1 $cell_names2]
    set diff_cell_names21 [struct::set difference $cell_names2 $cell_names1]
    if {[llength $diff_cell_names12] > 0} {
        puts $diff "CELLS: In $project1, not $project2: $diff_cell_names12"
    }
    if {[llength $diff_cell_names21] > 0} {
        puts $diff "CELLS: In $project2, not $project1: $diff_cell_names21"
    }
    
    set cell_names [struct::set intersect $cell_names1 $cell_names2]
    foreach cell_name $cell_names {
        current_project $project1
        set cell [get_cells $cell_name]
        set properties1 [list_property $cell]
        set bel1 [subst [get_bels -quiet -of_objects $cell]]
        set bel_pins1 [dict create]
        foreach cell_pin [get_pins -quiet -of_objects $cell] {
            dict set bel_pins1 [get_name $cell_pin] [subst [get_bel_pins -quiet -of_objects $cell_pin]]
        }
        current_project $project2
        set cell [get_cells $cell_name]
        set properties2 [list_property [get_cells $cell_name]]
        set bel2 [subst [get_bels -quiet -of_objects [get_cells $cell_name]]]
        set bel_pins2 [dict create]
        foreach cell_pin [get_pins -quiet -of_objects $cell] {
            dict set bel_pins2 [get_name $cell_pin] [subst [get_bel_pins -quiet -of_objects $cell_pin]]
        }
        
        if {$bel1 != $bel2} {
            puts $diff "CELL ($cell_name): BEL: $project1=$bel1, $project2=$bel2"
        }
        
        set diff_cell_pins12 [struct::set difference [dict keys $bel_pins1] [dict keys $bel_pins2]]
        set diff_cell_pins21 [struct::set difference [dict keys $bel_pins2] [dict keys $bel_pins1]]
        if {[llength $diff_cell_pins12] > 0} {
            puts $diff "CELL ($cell_name): CELL PINS: In $project1, not $project2: $diff_cell_pins12"
        }
        if {[llength $diff_cell_pins21] > 0} {
            puts $diff "CELL ($cell_name): CELL PINS: In $project2, not $project1: $diff_cell_pins21"
        }
        set cell_pins [struct::set intersect [dict keys $bel_pins1] [dict keys $bel_pins2]]
        
        foreach cell_pin $cell_pins {
            if {[dict get $bel_pins1 $cell_pin] != [dict get $bel_pins2 $cell_pin]} {
                puts $diff "CELL ($cell_name): CELL PIN ($cell_pin): BEL PIN: $project1=[dict get $bel_pins1 $cell_pin], $project2=[dict get $bel_pins2 $cell_pin]"
            }
        }
        
        set diff_properties12 [struct::set difference $properties1 $properties2]
        set diff_properties21 [struct::set difference $properties2 $properties1]
        if {[llength $diff_properties12] > 0} {
            puts $diff "CELL ($cell_name): PROPERTIES: In $project1, not $project2: $diff_properties12"
        }
        if {[llength $diff_properties21] > 0} {
            puts $diff "CELL ($cell_name): PROPERTIES: In $project2, not $project1: $diff_properties21"
        }
        
        set properties [struct::set intersect $properties1 $properties2]
        
        foreach property $properties {
            if {[lsearch -exact $SKIP_CELL_PROPERTIES $property] != -1} continue
            
            current_project $project1
            set value1 [get_property -quiet $property [get_cells $cell_name]]
            current_project $project2
            set value2 [get_property -quiet $property [get_cells $cell_name]]
            
            if {$value1 != $value2} {
                puts $diff "CELL ($cell_name): PROPERTY ($property): $project1=$value1, $project2=$value2"
            }
        }
    }
    
    set diff_net_names12 [struct::set difference $net_names1 $net_names2]
    set diff_net_names21 [struct::set difference $net_names2 $net_names1]
    if {[llength $diff_net_names12] > 0} {
        puts $diff "NETS: In $project1, not $project2: $diff_net_names12"
    }
    if {[llength $diff_net_names21] > 0} {
        puts $diff "NETS: In $project2, not $project1: $diff_net_names21"
    }
    
    set net_names [struct::set intersect $net_names1 $net_names2]
    foreach net_name $net_names {
        current_project $project1
        set net [get_nets $net_name]
        set properties1 [list_property $net]
        set nodes1 [list]
        foreach node [get_nodes -quiet -of_objects $net] {
            lappend nodes1 [get_property NAME $node]
        }
        current_project $project2
        set net [get_nets $net_name]
        set properties2 [list_property $net]
        set nodes2 [list]
        foreach node [get_nodes -quiet -of_objects $net] {
            lappend nodes2 [get_property NAME $node]
        }
        
        set diff_nodes12 [struct::set difference $nodes1 $nodes2]
        set diff_nodes21 [struct::set difference $nodes2 $nodes1]
        if {[llength $diff_nodes12] > 0} {
            puts $diff "NET ($net_name): NODES: In $project1, not $project2: $diff_nodes12"
        }
        if {[llength $diff_nodes21] > 0} {
            puts $diff "NET ($net_name): NODES: In $project2, not $project1: $diff_nodes21"
        }
        
        set diff_properties12 [struct::set difference $properties1 $properties2]
        set diff_properties21 [struct::set difference $properties2 $properties1]
        if {[llength $diff_properties12] > 0} {
            puts $diff "NET ($net_name): PROPERTIES: In $project1, not $project2: $diff_properties12"
        }
        if {[llength $diff_properties21] > 0} {
            puts $diff "NET ($net_name): PROPERTIES: In $project2, not $project1: $diff_properties21"
        }
        
        set properties [struct::set intersect $properties1 $properties2]
        
        foreach property $properties {
            if {[lsearch -exact $SKIP_NET_PROPERTIES $property] != -1} continue
            
            current_project $project1
            set value1 [get_property -quiet $property [get_nets $net_name]]
            current_project $project2
            set value2 [get_property -quiet $property [get_nets $net_name]]
            
            if {$value1 != $value2} {
                puts $diff "NET ($net_name): PROPERTY ($property): $project1=$value1, $project2=$value2"
            }
        }
    }
    
    set diff_port_names12 [struct::set difference $port_names1 $port_names2]
    set diff_port_names21 [struct::set difference $port_names2 $port_names1]
    if {[llength $diff_port_names12] > 0} {
        puts $diff "PORTS: In $project1, not $project2: $diff_port_names12"
    }
    if {[llength $diff_port_names21] > 0} {
        puts $diff "PORTS: In $project2, not $project1: $diff_port_names21"
    }
    set port_names [struct::set intersect $port_names1 $port_names2]
    foreach port_name $port_names {
        current_project $project1
        set port [get_ports $port_name]
        set properties1 [list_property $port]
        set pkg_pin1 [subst [get_package_pins -quiet -of_objects $port]]
        set bel_pins1 [dict create]
        foreach cell_pin [get_pins -quiet -of_objects $cell] {
            dict set bel_pins1 [get_name $cell_pin] [subst [get_bel_pins -quiet -of_objects $cell_pin]]
        }
        current_project $project2
        set cell [get_cells $cell_name]
        set properties2 [list_property [get_cells $cell_name]]
        set bel2 [subst [get_bels -quiet -of_objects [get_cells $cell_name]]]
        set bel_pins2 [dict create]
        foreach cell_pin [get_pins -quiet -of_objects $cell] {
            dict set bel_pins2 [get_name $cell_pin] [subst [get_bel_pins -quiet -of_objects $cell_pin]]
        }
        
        if {$bel1 != $bel2} {
            puts $diff "CELL ($cell_name): BEL: $project1=$bel1, $project2=$bel2"
        }
        
        set diff_cell_pins12 [struct::set difference [dict keys $bel_pins1] [dict keys $bel_pins2]]
        set diff_cell_pins21 [struct::set difference [dict keys $bel_pins2] [dict keys $bel_pins1]]
        if {[llength $diff_cell_pins12] > 0} {
            puts $diff "CELL ($cell_name): CELL PINS: In $project1, not $project2: $diff_cell_pins12"
        }
        if {[llength $diff_cell_pins21] > 0} {
            puts $diff "CELL ($cell_name): CELL PINS: In $project2, not $project1: $diff_cell_pins21"
        }
        set cell_pins [struct::set intersect [dict keys $bel_pins1] [dict keys $bel_pins2]]
        
        foreach cell_pin $cell_pins {
            if {[dict get $bel_pins1 $cell_pin] != [dict get $bel_pins2 $cell_pin]} {
                puts $diff "CELL ($cell_name): CELL PIN ($cell_pin): BEL PIN: $project1=[dict get $bel_pins1 $cell_pin], $project2=[dict get $bel_pins2 $cell_pin]"
            }
        }
        
        set diff_properties12 [struct::set difference $properties1 $properties2]
        set diff_properties21 [struct::set difference $properties2 $properties1]
        if {[llength $diff_properties12] > 0} {
            puts $diff "CELL ($cell_name): PROPERTIES: In $project1, not $project2: $diff_properties12"
        }
        if {[llength $diff_properties21] > 0} {
            puts $diff "CELL ($cell_name): PROPERTIES: In $project2, not $project1: $diff_properties21"
        }
        
        set properties [struct::set intersect $properties1 $properties2]
        
        foreach property $properties {
            if {[lsearch -exact $SKIP_CELL_PROPERTIES $property] != -1} continue
            
            current_project $project1
            set value1 [get_property -quiet $property [get_cells $cell_name]]
            current_project $project2
            set value2 [get_property -quiet $property [get_cells $cell_name]]
            
            if {$value1 != $value2} {
                puts $diff "CELL ($cell_name): PROPERTY ($property): $project1=$value1, $project2=$value2"
            }
        }
    }
    
    current_project $project1
    close_project
    
    if {$filename != ""} {close $diff}
}

## Get the route-throughs in a design. This includes both BEL- and site-level route-throughs.
# @return A list of <CODE>bel_pin</CODE> objects, one for each route-through.
proc ::tincr::designs::get_route_throughs {} {
    set route_throughs [dict create]

    foreach pip [get_pips -quiet -of_objects [get_nets -hierarchical] -filter IS_PSEUDO] {
        set site_pin [get_site_pins -quiet -of_objects [get_nodes -quiet -uphill -of_objects $pip]]
        if {[get_property IS_USED [get_sites -quiet -of_objects $site_pin]]} continue
        
        # This foreach loop just filters out the correct bel_pin
        foreach snk [::tincr::sites get_site_wire_sinks $site_pin] {
            if {[::tincr::get_class $snk] == "bel_pin" && [::tincr::bels is_lut6 [::tincr::bels get -of_objects $snk]]} {
                dict set route_throughs $snk [get_nets -quiet -of_objects $pip]
            }
        }
    }
    
    foreach bel_pin [get_bel_pins -quiet -of_objects [get_pins -hierarchical]] {
        set bel [::tincr::bels get -quiet -of_objects $bel_pin]
        if {[::tincr::bels is_lut $bel] && ![get_property IS_USED $bel]} {
            dict set route_throughs $bel_pin [get_nets -quiet -of_objects [get_pins -quiet -of_objects $bel_pin]]
        }
    }
    
    return $route_throughs
}

## Get the routed wire-length in terms of tiles that nets traverse
proc ::tincr::designs::get_routed_tilelength {} {
    set tile_length 0

    foreach net [get_nets] {
	    incr tile_length [::tincr::nets::get_num_tiles $net]
    }
    
    return $tile_length
}

proc ::tincr::designs::get_critical_delay {} {
    # Use "report_property [get_timing_paths]" to see other delays of interest
    return [get_property DATAPATH_DELAY [get_timing_paths -nworst 1]]
}

## Write this design to an electronic design interchange format (EDIF) file.
# @param filename The file that this design's EDIF representation will be written to.
proc ::tincr::designs::edif { filename } {
    return [write_edif $filename]
}

## Get a list of all buses in the current design.
# @return A list of all buses in the current design.
proc ::tincr::designs::get_buses {} {
    set buses [list]
    
    foreach net [get_nets -filter {BUS_WIDTH != ""}] {
        set bus [get_property BUS_NAME $net]
        if { [lsearch $buses $bus] == -1 } {
            lappend buses $bus
        }
    }
    
    set buses [lsort $buses]
    
    return $buses
}

## Get a dictionary containing information about all of the buses in the current design.
# The dict format is as follows:
# \code
# buses
# |
# |->    <bus0>
# |->    direction = IN/OUT/INOUT
# |->    start = start wire
# |->    stop = end wire
# |->    width = bus width
# +->    ports = { <port0>, <port1>, ... }
# |->    <bus1>
# :
# \endcode
# @return A Tcl dict object containing bus information.
proc ::tincr::designs::get_design_buses { } {
    # Summary:
    

    # Argument Usage:

    # Return Value:
    # 


    # Categories: xilinxtclstore, byu, tincr, design

    # Notes:
    # The dict format is as follows:
    # buses
    # |
    # |->    <bus0>
    # |->    direction = IN/OUT/INOUT
    # |->    start = start wire
    # |->    stop = end wire
    # |->    width = bus width
    # +->    ports = { <port0>, <port1>, ... }
    # |->    <bus1>
    # :

    set buses [dict create]
    
    set ports [dict create]
    foreach port [get_ports -filter {BUS_WIDTH != ""}] {
        set name [get_property BUS_NAME $port]
        
        if { ![dict exists $buses $name] } {
            dict set buses $name direction [get_property BUS_DIRECTION $port]
            dict set buses $name start [get_property BUS_START $port]
            dict set buses $name stop [get_property BUS_STOP $port]
            dict set buses $name width [get_property BUS_WIDTH $port]
        }
        
        dict lappend ports $name $port
    }
    
    dict for {bus port} $ports {
        dict set buses $bus ports $port
    }
    
    return $buses
}

## Remove the route-throughs in a design. This function replaces all route-throughs with <CODE>BUF</CODE> cells.
proc ::tincr::designs::remove_route_throughs {route_throughs} {
#    ::array set rt_bels {}
#    ::foreach net [::get_nets -hierarchical $nets] {
#        ::set bels [::get_bels -quiet -of_objects $net *LUT*]
#        
#        ::foreach bel_pin [::get_bel_pins -quiet -of_objects $net *LUT*] {
#            # string range is faster than regex
#            ::set bel [::string range $bel_pin 0 [::string last / $bel_pin]-1]
#            
#            ::if {([::lsearch $bels $bel] == -1) && ([::get_property IS_USED [::get_bels $bel]] == 0)} {
#                ::array set rt_bels [::list $bel 0]
#            }
#        }
#    }
#    ::return [::get_bels -quiet [::split [::array names rt_bels]]]
    
#    set route_throughs [get_route_throughs]
    
    foreach bel_pin [dict keys $route_throughs] {
        set net [dict get $route_throughs $bel_pin]
        set bel [::tincr::bels get -of_objects $bel_pin]
        
        set placements [dict create]
        foreach cell [get_cells -quiet -of_objects $net] {
            dict set placements $cell [get_bels -of_objects $cell]
        }
        
        puts $bel
    }
}
