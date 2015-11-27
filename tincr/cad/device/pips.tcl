## @file pips.tcl
#  @brief Query <CODE>pip</CODE> objects in Vivado.
#
#  The <CODE>pips</CODE> ensemble provides procs that query a device's programmable interconnect points (PIPs).

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
	namespace export pips
}

## @brief The <CODE>pips</CODE> ensemble encapsulates the <CODE>pip</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::pips {
	namespace export \
		test \
		get \
		get_info \
		get_start \
		get_end \
		between_nodes \
		hops \
		is_route_through
	namespace ensemble create
}

proc ::tincr::pips::test {args} {
	source_with_args [file join $::env(TINCR_PATH) tincr_test cad device pips all.tcl] {*}$args
}

proc ::tincr::pips::get { args } {
	return [get_pips {*}$args]
}

## Get information about a PIP that can be found by parsing its name.
# @param node The <CODE>pip</CODE> object or PIP name to query.
# @param info What information to get about the PIP. Valid values include "tile", "type", "input", "direction", or "output".
# @return A string containing the specified information.
proc ::tincr::pips::get_info { pip {info pip} } {
	# TODO Expand this proc into separate procs, one for each "info"
	if {[regexp {(\w+)/(\w+).(\w+)(->>|->|<<->>)(\w+)} $pip matched tile type input direction output]} {
		return [subst $[subst $info]]
	} else {
		error "ERROR: \"$pip\" isn't a valid PIP name."
	}
}

## Get the source node of a PIP.
# @param pip The <CODE>pip</CODE> object.
# @return The <CODE>node</CODE> object that sources <CODE>pip</CODE>.
proc ::tincr::pips::get_start { args } {
	# TODO Get rid of parse_args by splitting this into two procs: get_start_wire and get_start_node.
	set node 0
	set wire 0
	::tincr::parse_args {} {node wire} {} {pip} $args
	
	if {$node} {
		return [get_nodes -uphill -of_objects $pip]
	} elseif {$wire} {
		return [get_wires -uphill -of_objects $pip]
	}
	
	return {}
}

## Get the sink node of a PIP.
# @param pip The <CODE>pip</CODE> object.
# @return The <CODE>node</CODE> object that is sourced by <CODE>pip</CODE>.
proc ::tincr::pips::get_end { args } {
	# TODO Get rid of parse_args by splitting this into two procs: get_start_wire and get_start_node.
	set node 0
	set wire 0
	::tincr::parse_args {} {node wire} {} {pip} $args
	
	if {$node} {
		return [get_nodes -downhill -of_objects $pip]
	} elseif {$wire} {
		return [get_wires -downhill -of_objects $pip]
	}
	
	return {}
}

## Get the PIP that connects two nodes.
# @param node1 The first <CODE>node</CODE> object.
# @param node2 The second <CODE>node</CODE> object.
# @return The <CODE>pip</CODE> object that connects these two nodes, if any.
proc ::tincr::pips::between_nodes {node1 node2} {
	return [::struct::set union [::struct::set intersect [get_pips -downhill -of_objects $node1] [get_pips -uphill -of_objects $node2]] [::struct::set intersect [get_pips -downhill -of_objects $node2] [get_pips -uphill -of_objects $node1]]]
}

## Get the set of PIPs that are some number of hops away from the given PIP. In this context, a "hop" refers the traversal of one node.
# @param pip The <CODE>pip</CODE> object.
# @param hops An integer specifying the number of hops away from <CODE>pip</CODE>.
# @return A list of <CODE>pip</CODE> objects that are <CODE>hops</CODE> nodes downhill from <CODE>pip</CODE>.
proc ::tincr::pips::hops {pip hops} {
	set pips $pip
	
	for {set i 0} {$i < $hops} {incr i} {
		set pips [get_pips -downhill -of_objects $pips]
	}
	
	return $pips
}

## Is this a route-through PIP?
# @param pip The <CODE>pip</CODE> object.
# @return True (1) if <CODE>pip</CODE> is a route-through PIP, false (0) otherwise.
proc ::tincr::pips::is_route_through { pip } {
	return [get_property IS_PSEUDO $pip]
}
