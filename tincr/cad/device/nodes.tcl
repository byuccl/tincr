## @file nodes.tcl
#  @brief Query <CODE>node</CODE> objects in Vivado.
#
#  The <CODE>nodes</CODE> ensemble provides procs that query a device's nodes.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export nodes
}

## @brief The <CODE>noes</CODE> ensemble encapsulates the <CODE>node</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::nodes {
    namespace export \
        test \
        get \
        get_source \
        get_sinks \
        get_info \
        exist \
        hops \
        between_pips \
        manhattan_distance
    namespace ensemble create
}

proc ::tincr::nodes::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device nodes all.tcl] {*}$args
}

proc ::tincr::nodes::get { args } {
    return [get_nodes {*}$args]
}

## Get a node's source wire.
# @param node The node object to query.
# @return The wire object that sources the node.
proc ::tincr::nodes::get_source_wire { args } {
    # TODO Fix this proc to operate correctly with normal parameters (get rid of parse_args)
    set wire 0
    set pip 0
    set site_pin 0
    tincr::parse_args {} {wire pip site_pin} {} {node} $args
    
    if {!$wire && !$pip && !$site_pin} {
        set pip 1
        set site_pin 1
    }
    
    set sources [list]
    
    if {$wire} {
        set sources [concat $sources [get_wires -of_object $node -filter {NUM_UPHILL_PIPS!=0 || IS_OUTPUT_PIN}]]
    }
    
    if {$pip} {
        set sources [concat $sources [get_pips -quiet -uphill -of_object $node]]
    }
        
    if {$site_pin} {
        set sources [concat $sources [get_site_pins -quiet -of_object $node -filter {DIRECTION==OUT}]]
    }

    return $sources
}

## Get a node's sink wires.
# @param  The <CODE>node</CODE> object.
# @return A list of <CODE>wire</CODE> objects that are sourced by the node.
proc ::tincr::nodes::get_sinks { args } {
    set wires 0
    set pips 0
    set site_pins 0
    tincr::parse_args {} {wires pips site_pins} {} {node} $args
    
    if {!$wires && !$pips && !$site_pins} {
        set pips 1
        set site_pins 1
    }
    
    set sinks [list]
    
    if {$wires} {
        set sinks [concat $sinks [get_wires -of_object $node -filter {NUM_DOWNHILL_PIPS!=0 || IS_INPUT_PIN}]]
    }
    
    if {$pips} {
        set sinks [concat $sinks [get_pips -quiet -downhill -of_object $node]]
    }
        
    if {$site_pins} {
        set sinks [concat $sinks [get_site_pins -quiet -of_object $node -filter {DIRECTION==IN}]]
    }

    return $sinks
}

## Get information about a node that can be found by parsing its name.
# @param node The <CODE>node</CODE> object or node name to query.
# @param info What information to get about the node. Valid values include "tile" or "name".
# @return A string containing the specified information.
proc ::tincr::nodes::get_info { node {info node} } {
    # TODO Expand this proc into separate procs, one for each "info"
    if {[regexp {(\w+)/(\w+)} $node matched tile name]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$node\" isn't a valid node name."
    }
}

## Get whether or not a node actually exists. NOTE: This may be deprecated.
# @param node The <CODE>node</CODE> object to query.
# @return True (1) if the node exists, false (0) otherwise.
proc ::tincr::nodes::exist { node } {
    return [expr {$node != "" && ([get_property IS_INPUT_PIN $node] || [get_property IS_OUTPUT_PIN $node] || ([get_pips -quiet -uphill -of $node] != "" && [get_pips -quiet -downhill -of $node] != ""))}] 
}

## Get the set of nodes that are some number of hops away from the given node. In this context, a "hop" refers the traversal of one PIP.
# @param node The <CODE>node</CODE> object.
# @param hops An integer specifying the number of hops away from <CODE>node</CODE>.
# @return A list of <CODE>node</CODE> objects that are <CODE>hops</CODE> PIPs downhill from <CODE>node</CODE>.
proc ::tincr::nodes::hops { node hops } {
    set nodes $node
    
    for {set i 0} {$i < $hops} {incr i} {
        set nodes [get_nodes -downhill -of_objects $nodes]
    }
    
    return $nodes
}

## Get the node that connects two PIPs.
# @param pip1 The first <CODE>pip</CODE> object.
# @param pip2 The second <CODE>pip</CODE> object.
# @return The node that connects these two PIPs, if any.
proc ::tincr::nodes::between_pips {pip1 pip2} {
    return [::struct::set union [::struct::set intersect [get_nodes -downhill -of_objects $pip1] [get_nodes -uphill -of_objects $pip2]] [::struct::set intersect [get_nodes -downhill -of_objects $pip2] [get_nodes -uphill -of_objects $pip1]]]
}

## Get the Manhattan distance of a node.
# @param node The <CODE>node</CODE> object.
# @return An integer specifying the Mahattan distance of <CODE>node</CODE> in terms of tiles.
proc ::tincr::nodes::manhattan_distance { node } {
    # TODO This feature is planned
}
