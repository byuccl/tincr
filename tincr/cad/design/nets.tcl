## @file nets.tcl
#  @brief Query and modify <CODE>net</CODE> objects in Vivado.
#
#  The <CODE>nets</CODE> ensemble provides procs that query or modify a design's nets.

package provide tincr.cad.design 0.0

package require Tcl 8.5
package require struct 2.1
package require control 0.1.3

package require tincr.cad.util 0.0

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export nets
}

## @brief The <CODE>nets</CODE> ensemble encapsulates the <CODE>net</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::nets {
    namespace export \
        test \
        new \
        set_name \
        get \
        get_source \
        get_source_node \
        get_sinks \
        copy \
        float \
        get_root \
        replace_source \
        manhattan_distance \
        get_source_tile \
        absolute_routing_string \
        get_branched_routes \
        fix_all \
        add_pip \
        add_node \
        get_neighbor_nodes \
        get_next_node2 \
        get_next_node \
        recurse_route \
        format_routing_string \
        list_nodes \
        recurse_pips \
        list_pips \
        of_bus \
        get_route_throughs \
        unroute \
        split_route
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>nets</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::nets::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design nets all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>nets</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::nets::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design nets "$proc.test"] {*}$args
}

## Create a new net.
# @param name The name of the new net.
# @return The newly created cell.
proc ::tincr::nets::new { name } {
    return [create_net $name]
}

## The <code>NAME</code> property of a net (or any Vivado object for that matter)
# is read-only. This function lets you pseudo-rename a net by creating a duplicate
# net with the new name and deleting the old net.
# @param net The <CODE>net</CODE> object.
# @param name The name of the new net.
# @return The net with the new name.
proc ::tincr::nets::set_name { name } {
    # TODO Special care must be taken when renaming a net that is a "bit" of a bus (i.e. whole bus must be renamed, not just the individual "bit" net)
}

## Queries Vivado's object database for a list of <CODE>net</CODE> objects that fit the given criteria. At the moment, this is just a wrapper function for Vivado's <CODE>get_nets</CODE> command.
proc ::tincr::nets::get { args } {
    return [get_nets {*}$args]
}

## Get the source pin or port of a net.
# @param The <CODE>net</CODE> object.
# @return The <CODE>pin</CODE> or <CODE>port</CODE> object that sources the net.
proc ::tincr::nets::get_source { net } {
    return [::struct::set union [get_pins -quiet -of_objects $net -filter {DIRECTION==OUT}] [get_ports -quiet -of_objects $net -filter {DIRECTION==IN}]]
}

## Get the node that stands at the head of a routed net.
# @param net The <CODE>net</CODE> object.
# @return The <CODE>node</CODE> object that sources the net.
proc ::tincr::nets::get_source_node { net } {
    set source {}
    set source_name [get_property SOURCE_NODE $net]
    if {$source_name == ""} {
        # Find the source node and cache it
        create_property SOURCE_NODE net
        
            ::struct::graph routing_graph
            routing_graph node insert {*}[get_nodes -quiet -of_objects $net]
            foreach node [routing_graph nodes] {
                    set node [get_nodes -quiet $node]
                    set downhill_pips [::struct::set intersect [get_pips -quiet -downhill -of_objects $node] [get_pips -quiet -of_objects $net]]
                    if {[llength $downhill_pips] == 0} continue
                        set downhill_nodes [::struct::set intersect [get_nodes -quiet -downhill -of_objects $downhill_pips] [get_nodes -quiet -of_objects $net]]
                        foreach downhill_node $downhill_nodes {
                    routing_graph arc insert $node $downhill_node
                    }
            }
            
            foreach node [routing_graph nodes] {
                set node [get_nodes -quiet $node]
                if {[llength [routing_graph nodes -in $node]] == 0} {
                set source $node
                set_property SOURCE_NODE $node $net
                break
                }
            }
            
            routing_graph destroy
    } else {
        set source [get_nodes -quiet -of_objects $net $source_name]
    }
    
    return $source
    
    # The following line doesn't retrieve sources for all types of nets (i.e. fails on hierarchical nets)
#    return [get_pins -quiet -of_objects $net -filter {DIRECTION==OUT && IS_LEAF}]
}

## Get the sink pins and/or ports of a net.
# @param The <CODE>net</CODE> object.
# @return The <CODE>pin</CODE> and/or <CODE>port</CODE> objects that the net sources.
proc ::tincr::nets::get_sinks { net } {
    return [get_pins -quiet -of_objects $net -filter {DIRECTION==IN && IS_LEAF}]
}

## Copies the given nets, including all properties except for routing (i.e. <code>ROUTE</code>, <code>FIXED_ROUTE</code>, etc.).
# @param nets The <CODE>net</CODE> objects to copy.
# @param names The new names of the nets. If this parameter is omitted or has fewer elements than <CODE>nets</CODE>, a default name will be assigned for the remaining nets.
# @return A list of the net copies.
proc ::tincr::nets::copy { nets {names ""} } {
    if {[llength $nets] == 1} {
        set nets [list $nets]
    }
    if {[llength $names] == 1} {
        set names [list $names]
    }
    
    # TODO Check to make sure a net with the same name (*_copy) doesn't already exist?
    for {set i [llength $names]} {$i < [llength $nets]} {incr i} {
        lappend names "[::tincr::get_name [lindex $nets $i]]_copy"
    }
    
    for {set i 0} {$i < [llength $nets]} {incr i} {
        set net [lindex $nets $i]
        set name [lindex $names $i]
        
        # TODO Create the new net with the new name
        # TODO Connect the new net to the old net's pins
    }
}

## Unroute a net and disconnect it from any pins to which it was connected.
# @param net The <CODE>net</CODE> object to disconnect.
# @return The net's former source pin, if any.
proc ::tincr::nets::float { args } {
    ::tincr::parse_args {} {} {} {net} $args
    
    set source_pin [nets get_source $net]
    disconnect_net -net $net -objects [get_pins -quiet -of_objects $net]
    set_property ROUTE {} $net
    
    return $source_pin
}

## Get the top-level net of a hierarchical net.
# @param net The <CODE>net</CODE> object.
# @return The top-level net of the net.
proc ::tincr::nets::get_root { net } {
    set root_net $net
    while {[get_property NAME $root_net] != [get_property PARENT $root_net]} {
        set root_net [get_nets [get_property PARENT $root_net]]
    }
    return $root_net
}

## Replaces the source of the given net with the given pin.
# @param net The <CODE>net</CODE> object.
# @param new_source The pin to replace the net's source with.
proc ::tincr::nets::replace_source { net new_source } {
    #TODO Add support for ports
    
    if {[get_property DIRECTION $new_source] != "OUT"} {
        error "ERROR: The pin $new_source is not an output pin."
    } elseif {[get_property IS_CONNECTED $new_source]} {
        error "ERROR: The pin $new_source is already connected to the net [get_nets -of $new_source]."
    }

    # Get current source pin
    set old_source [get_pins -of_objects $net -leaf -filter {DIRECTION==OUT}]
    
    # Cannot connect pins for placed cells
    set new_cell [get_cells -quiet -of_objects $new_source]
    set new_bel [get_bels -quiet -of_objects $new_cell]

    # Disconnect the original source and unplace all cells 
    disconnect_net -net $net -objects $old_source
    
    if {$new_bel != ""} {
        set new_bel_fixed [get_property IS_BEL_FIXED $new_cell]
        set new_loc_fixed [get_property IS_LOC_FIXED $new_cell]
        unplace_cell -quiet $new_cell
    }
    
    set other_cells {}
    foreach other_cell [get_cells -of_objects [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION!=OUT}]] {
        set placed_bel [get_bels -quiet -of_objects $other_cell]
        if {$placed_bel != ""} {
            dict set other_cells $other_cell bel $placed_bel
            dict set other_cells $other_cell is_bel_fixed [get_property IS_BEL_FIXED $other_cell]
            dict set other_cells $other_cell is_loc_fixed [get_property IS_LOC_FIXED $other_cell]
            unplace_cell -quiet $other_cell
        }
    }
    
    # Connect the new cell and re-place everything 
    connect_net -hier -net $net -objects $new_source
    
    dict for { original_cell placement_info } $other_cells {
        dict with placement_info {
            # There is a bug in Vivado (surprise!). First class objects do not 
            # behave like strings for place_cell, so I must get the name.
            place_cell -quiet [subst $original_cell] [subst $bel]
            set_property -quiet IS_BEL_FIXED $is_bel_fixed $original_cell
            set_property -quiet IS_LOC_FIXED $is_loc_fixed $original_cell
        }
    }
    
    if {$new_bel != ""} {
        place_cell -quiet [subst $new_cell] [subst $new_bel]
        set_property -quiet IS_BEL_FIXED $new_bel_fixed $new_cell
        set_property -quiet IS_LOC_FIXED $new_loc_fixed $new_cell
    }
}

## Reports the Manhattan distance of a net.
# @param net The <CODE>net</CODE> object.
# @return The Manhattan distance of a net as an integer.
proc ::tincr::nets::manhattan_distance { net } {
    set tiles [get_tiles -of_objects $net]
    
    regexp {X(\d+)Y(\d+)} [lindex $tiles 0] match x y
    
    set min_x $x
    set max_x $x
    set min_y $y
    set max_y $y
    
    set num_tiles [llength $tiles]
    for {set i 1} {$i < $num_tiles} {incr i} {
        regexp {X(\d+)Y(\d+)} [lindex $tiles $i] match x y
        if {$x > $max_x} {
            set max_x $x
        } elseif {$x < $min_x} {
            set min_x $x
        }
        if {$y > $max_y} {
            set max_y $y
        } elseif {$y < $min_y} {
            set min_y $y
        }
    }
    
    return [expr {$max_x - $min_x + $max_y - $min_y}] 
}

## Get the tile that a net is sourced from. Only applicable when the source is placed.
# @param net The <CODE>net</CODE> object
# @return The <CODE>tile</CODE> object of the pin that sources the net.
proc ::tincr::nets::get_source_tile { net } {
    return [get_tiles -of_objects [get_sites -of_objects [get_cells -of_objects [get_pins -of_objects $net -leaf -filter {DIRECTION==OUT}]]]]
}

## Get a net's absolute routing string. By default, the string stored in a net's <CODE>ROUTE</CODE> property lists constituent nodes by their relative names only. This function expands their names to include their absolute name.
# @param net The <CODE>net</CODE> object.
proc ::tincr::nets::absolute_routing_string { net } {
    set map {}
    
    foreach node [get_nodes -of_objects $net] {
        set slash [string last / $node]
        set node_name [string range $node $slash+1 end]
        
        # create a map of relative names to specific names where duplicates map to ""
        if {[dict exists $map $node_name]} {
            dict set map $node_name {}
        } else {
            dict set map $node_name [string range $node 0 $slash]
        }
    }
    
    # build the new routing string
    set route {}

    foreach next [split [get_property ROUTE $net]] {
        if {[dict exists $map $next]} {
            set next [dict get $map $next]$next
        }
        append route " $next"
    }
    return $route
}

## Get all nets that have a branch.
# @return Any nets in the current design that have a branch (i.e. more than one sink).
proc ::tincr::nets::get_branched_routes {} {
    return [get_nets -filter {PIN_COUNT>2}]
}

## Fixes the routes of all nets in the design.
proc ::tincr::nets::fix_all {} {

    foreach net [get_nets] {
        set route [get_property ROUTE $net]
        
        if {$route != "\{\}"} {
            # puts "$route"
            set_property FIXED_ROUTE $route $net
        }
    }
}

## Add a PIP to an unrouted, fully, or partially routed net. Adding a PIP to the middle of a routed or partially routed net creates an antenna. Adding a PIP to the end of an unrouted or partially routed net extends the route. This proc can be used in the Vivado GUI to "click-and-route" with the following command: \code{.tcl}::tincr::add_pip $net [get_selected_objects]\endcode
# @param net The <CODE>net</CODE> object to add the PIP to.
# @param pip The PIP that will be added to the net.
# @return Returns the number of nodes added to the net. This will be 0 if there was a problem, 1 if the net was already partially routed, or 2 if the net was initially unrouted.
proc ::tincr::nets::add_pip { net pip } {
    # Make sure the pip isn't already in the net
    if {[llength [get_pips -quiet -of_objects $net $pip]]} {
        puts "ERROR: $pip is already in $net."
        return 0
    }
    
    set nodes [get_nodes -quiet -of_objects $net]
    if {[llength $nodes]} { ;# (Partially) routed net
        set new_node [get_nodes -downhill -of_objects $pip]
        foreach node $nodes {
            if {[get_pips -quiet -downhill -of_objects $node $pip] != ""} {
                set route [split [get_property ROUTE $net]]
                set insert_after -1
    
                while {1} {                
                    # Start searching after the previous find until it works
                    set insert_after [lsearch -start $insert_after+1 $route [string range $node [string last / $node]+1 end]]
    
                    if {[lindex $route $insert_after+1] == "\}"} { ;# End of route
                        set new_route [join [linsert $route $insert_after+1 $new_node]]
                    } else { ;# Create branch
                        set new_route [join [linsert $route $insert_after+1 \{ $new_node \}]]
                    }
                    
                    # If set_property fails, then there are duplicate node names
                    if {![catch {set_property ROUTE $new_route $net}]} {
                        return 1
                    }
                }
            }
        }
    } else { ;# Unrouted net -- assumes unambiguous pin-to-pip mapping
        set new_route "[get_nodes -uphill -of_objects $pip] [get_nodes -downhill -of_objects $pip]"
        if {![catch {set_property ROUTE $new_route $net}]} {
            #puts "New route: [get_property ROUTE $net]"
            return 2
        }
    }
    
    puts "ERROR: $pip is not accessible from $net."
    return 0
}

## Add a node to an unrouted or fully or partially routed net.
# @param net The net to which to add the node.
# @param new_node The node that will be added to the net.
# @return Returns the number of nodes added to the net. This will be 0 if there was a problem or 1 if the node was successfully added.
proc ::tincr::nets::add_node { net new_node } {
    # Summary:
    # 

    # Argument Usage:
    # net : 
    # new_node : 

    # Return Value:
    # 

    # Categories: xilinxtclstore, byu, tincr, design

    # Notes:
    # Adding a node to the middle of a routed or partially routed net creates an antenna. Adding a node to the end of an unrouted or partially routed net extends the route. This proc can be used in the Vivado GUI to click-and-route with the following command: \code{.tcl}::tincr::add_node $net [get_selected_objects]\endcode

    set nodes [get_nodes -quiet -of_objects $net]
    # Make sure the node isn't already in the net
    if {[lsearch $nodes $new_node] != -1} {
        puts "ERROR: $new_node is already in $net."
        return 0
    }
    
    if {[llength $nodes]} { ;# (Partially) routed net
        foreach node $nodes {
            if {[get_nodes -quiet -downhill -of_objects $node $new_node] != ""} {
                set route [split [get_property ROUTE $net]]
                set insert_after -1
    
                # Keep trying in case of duplicate nodes
                while {1} {                
                    # Start searching after the previous find until it works
                    set insert_after [lsearch -start $insert_after+1 $route [string range $node [string last / $node]+1 end]]
    
                    if {[lindex $route $insert_after+1] == "\}"} { ;# End of route
                        #puts "New route: [join [linsert $route $insert_after+1 $new_node]]"
                        set new_route [join [linsert $route $insert_after+1 $new_node]]
                    } else { ;# Create branch
                        #puts "New route: [join [linsert $route $insert_after+1 \{ $new_node \}]]"
                        set new_route [join [linsert $route $insert_after+1 \{ $new_node \}]]
                    }
                    
                    # If set_property fails, then there are duplicate node names
                    if {![catch {set_property ROUTE $new_route $net}]} {
                        return 1
                    }
                }
            }
        }
    } else { ;# Unrouted net -- assumes unambiguous pin-to-node mapping
        if {![catch {set_property ROUTE $new_node $net}]} {
            #puts "New route: [get_property ROUTE $net]"
            return 1
        }
    }
    
    puts "ERROR: $new_node is not accessible from $net."
    return 0
}

## Get the nodes that neighbor a specified node in a net.
# @param net The <CODE>net</CODE> object.
# @param The node within the net to inspect.
# @return The neighbors of the specified node in the net.
proc ::tincr::nets::get_neighbor_nodes { net node } {
    set net_neighbors [list]
    set all_neighbors [get_nodes -of_object $node]
    
    foreach net_node [get_nodes -of $net] {
        if { [lsearch $all_neighbors $net_node] != -1 } {
            lappend net_neighbors $net_node
        }
    }
    
    return $net_neighbors
}

## Get the next node in a routed net.
# @param net The <CODE>net</CODE> object.
# @param node The node in question.
# @return The next node(s) in the net that comes after the given node.
proc ::tincr::nets::get_next_node2 {net node} {
#    ::tincr::parse_args {} {} {} {net node} $args
    
    # TODO: Verify that the first element in a routing string is never a list
    set source_node [lindex [list_nodes $net] 0 0]
    ::control::assert {[llength source_node] == 1}
    
    set result [::struct::set intersect [get_nodes -quiet -of_objects $net] [get_nodes -quiet -downhill -of_objects $node]]
    
    # The source node can never be the next node, but it can be downhill of a sink node
    # TODO: Write a test case for this ^
    if {$result == $source_node} {
        set result {}
    }
    
    return $result
}

## Get the next node in a routed net. Get the node with "name" in "net" after "node" (connected through a PIP).
# @param net The <CODE>net</CODE> object.
# @param node The node in question.
# @param name The expected name of the next node.
# @return The next node(s) in the net that comes after the given node.
proc ::tincr::nets::get_next_node { node net name } {

    if { $node == "" } {
        return [get_nodes -of_object [get_site_pin -of [get_source $net]]]
    } else {
#        set all_neighbors [get_nodes -of_object $node -filter "NAME =~ *$name"]
#        
#        foreach net_node [get_nodes -of $net -filter "NAME =~ *$name"] {
#            if { [lsearch $all_neighbors $net_node] != -1 } {
#                return [get_nodes $net_node]
#            }
#        }
        set next_node [struct::set intersect [get_nodes -quiet -of_object $net] [get_nodes -quiet -downhill -of_object $node "*$name"]]
        if {[llength $next_node] != 1} {
            error "ERROR The node \"$name\" that net \"$net\" traverses after node \"$node\" could not be found."
        }
        return $next_node
    }
}

## Recursively traverse a net and build its routing string. This recursive function uses variables in the caller to execute, so it must be called correctly. See the code in <CODE>::tincr::nets list_nodes</CODE> for an example.
# @param node The current <CODE>node</CODE> object.
# @return The routing string up to the current point in the net.
proc ::tincr::nets::recurse_route { node } {
    upvar net net
    upvar tokens tokens
    set nodes [list]
    
    while { [llength $tokens] != 0 } {
        # dequeue token
        set token [lindex $tokens 0]
        set tokens [lreplace $tokens 0 0]
        
        if { $token == "" || $token == "{}" } {
            continue
        } elseif { $token == "\{" } {
            lappend nodes [recurse_route $node]
        } elseif { $token == "\}" } {
            return $nodes
        } else {
            set node [get_next_node $node $net $token]
            lappend nodes $node
        }
    }
    
    return $nodes
}

## Remove unwanted < or > characters from a routing string.
# @param net The <CODE>net</CODE> object to correct.
# @return The corrected routing string.
proc ::tincr::nets::format_routing_string { net } {
    set route [get_property ROUTE $net]
    
    while { [string match "*<*>?*" $route] == 1 } {
        set route [string replace $route [string first < $route] [string first > $route] ""]
    }
    
    return $route
}

## Get the route of the specified net as a nested list. Each nested list represents a branch of the net. When printed, the output is identical to the directed routing string of the net. Note: This function flattens single-node branches (e.g. <CODE>{ ER1BEG1 }</CODE>) instead of including them as a nested list. This may cause Vivado to misinterpret the route if it is used a routing string.
# @param net The net from which to get nodes.
# @return The route as a list of nested lists.
proc ::tincr::nets::list_nodes { net } {
    set tokens [split [format_routing_string $net]]
    
    set nodes [recurse_route ""]
    
    return $nodes
}

## Recursively traverse the PIPs of a net. This recursive function uses variables in the caller to execute, so it must be called correctly. See the code in <CODE>::tincr::nets list_pips</CODE> for an example.
# @param node1 The current node.
# @param nodes The list of nodes.

proc ::tincr::nets::recurse_pips { node1 nodes } {
    upvar pips pips
    
    while { [llength $nodes] > 0 } {
        set node2 [lindex $nodes 0]
        set nodes [lreplace $nodes 0 0]
        
        if { [llength $node2] == 1 } {
            if { $node1 != "" } {
                set node2 [get_nodes $node2]
                # puts [get_pip_between_nodes $node1 $node2]
                lappend pips [get_pip_between_nodes $node1 $node2]
            }
        
            set node1 $node2
        } else {
            recurse_pips $node1 $node2
        }
    }
}

## Get the <CODE>pip</CODE> objects of a net. The list of pips is built by recursively traversing the net's route. This function produces results identical to Vivado's <CODE>get_pips</CODE> -of_objects $net.
# @param net The <CODE>net</CODE> object.
# @return A list of the <CODE>pip</CODE> objects in the net's route.
proc ::tincr::nets::list_pips { net } {
    set nodes [get_nodes_of_net $net]
    set pips [list]
    
    recurse_pips "" [lindex $nodes 0]
    
    return $pips
}

## Get the nets of a specified bus.
# @param bus The bus whose nets to get.
# @return The nets of the bus.
proc ::tincr::nets::of_bus { bus } {
    return [get_nets -filter "BUS_NAME == $bus"]
}

## Get all LUTs used as routing in the design.
# @param nets The nets in which to look for route-throughs.
# @return A list containing all LUTs used as route-throughs in the design.
proc ::tincr::nets::get_route_throughs { {nets *} } {
    array set rt_bels {}
    foreach net [get_nets -hierarchical $nets] {
        set bels [get_bels -quiet -of_objects $net *LUT*]
        
        foreach bel_pin [get_bel_pins -quiet -of_objects $net *LUT*] {
            # string range is faster than regex
            set bel [string range $bel_pin 0 [string last / $bel_pin]-1]
            
            if {([lsearch $bels $bel] == -1) && ([get_property IS_USED [get_bels $bel]] == 0)} {
                array set rt_bels [list $bel 0]
            }
        }
    }
    return [get_bels -quiet [split [array names rt_bels]]]
}

## Unroute a net.
# @param net The <CODE>net</CODE> object.
# @return The net's old route.
proc ::tincr::nets::unroute { net } {
    ::set route [::get_property ROUTE $net]
    ::set_property FIXED_ROUTE {} $net
    ::set_property ROUTE {} $net
    ::return $route
}

## Splits a branch off of a net's route at the node specified by "node"
# @param net The net whose route is to be split
# @param node The first node in the branch to be split off from the net's route
# @returns A two element list. The first element is the net's route excluding the branch, the second element is the branch starting at "node".
proc ::tincr::nets::split_route { args } {
    ::tincr::parse_args {} {} {split_net} {net node} $args
    
    set result [list_nodes $net]
    
    lappend result [recurse_split_route $node result 0]
    
    return $result
}

# This proc is internal.
proc ::tincr::nets::recurse_split_route { target var_name path } {
    upvar $var_name route
    set nodes [lindex $route $path]
    for {set i 0} {$i < [llength $nodes]} {incr i} {
        set element [lindex $nodes $i]
        
        if {[llength $element] == 1} {
            if {$element == $target} {
                set result [lrange $nodes $i [llength $nodes]-1]
                set old_branch [lrange $nodes 0 $i-1]
                if {[llength $old_branch] == 0} {
                    set parent_path [lrange $path 0 [llength $path]-2]
                    set child_index [lindex $path [llength $path]-1]
                    lset route $parent_path [lreplace [lindex $route $parent_path] $child_index $child_index]
                } elseif {[llength $old_branch] == 1} {
                    lset route $path [list [list $old_branch]]
                } else {
                    lset route $path $old_branch
                }
                return $result
            }
        } else {
            set result [recurse_split_route $target route [concat $path $i]]
            if {$result != ""} {
                return $result
            }
        }
    }
}
