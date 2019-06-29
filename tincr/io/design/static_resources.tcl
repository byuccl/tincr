package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
    write_static_resources 
}

## Identifies <b>used</b> site routethroughs present in a list of tiles 
# (like the tiles of a pblock) and writes these site rouethroughs to the 
# static.rsc file.
#
# @param tiles List of tiles in the reconfigurable region
# @param channel Output file handle
# TODO: Optimize this procedure.
proc write_rp_site_routethroughs { tiles channel } {
    set site_rts [list]
    set nets [get_nets -hierarchical]

    # Get all nodes that are in the tiles we care about and that also have nets
    set nodes [::struct::set intersect [get_nodes -quiet -of_objects $nets] [get_nodes -quiet -of_objects $tiles]]
    
    if {[llength $nodes] != 0} {

        # Get the list of nets that those nodes deal with
        set nets [get_nets -of_objects $nodes]
        
        # Get a subset of the PIPs that are within the tiles and are used in nets we care about.
        set tile_pips [lsort [get_pips -quiet -of_objects $tiles -filter {!IS_TEST_PIP && !IS_EXCLUDED_PIP}]]
        set net_pips [lsort [get_pips -quiet -of_objects $nets -filter {!IS_TEST_PIP && !IS_EXCLUDED_PIP}]]
        set pips [::struct::set intersect $tile_pips $net_pips]

        foreach pip $pips {
            # If the PIP is within the tiles of the pblock
            set uphill_node [get_nodes -quiet -uphill -of_object $pip]
            set downhill_node [get_nodes -quiet -downhill -of_object $pip]
                
            # A route-through PIP must have an uphill (source) and a downhill (sink) node
            if {$uphill_node != "" && $downhill_node != ""} {
                # If PSEUDO, it's a route-through PIP (and not a "real" PIP).
                if {[get_property IS_PSEUDO $pip]} {
                    set src_pin [get_site_pins -of_object [get_nodes -uphill -of_object $pip]]
                    lappend site_rts "[get_sites -of_object $src_pin]"
                }
            }
        }
    }
    # print the site routethroughs
    ::tincr::print_list -header "SITE_RTS" -channel $channel $site_rts
}

## Finds VCC/GND partition pins (out-of-context ports) in a design and writes them to the routing.rsc file.
#
# @param channel File handle to write to
# TODO: Migrate to tincr_checkpoints.tcl and output in routing.xdc for OOC checkpoints as well?
proc write_static_part_pins { rp_cell channel } {
    # Any pins in these lists will be VCC or GND part pins coming into the RP.
    set vcc_part_pins [list]
    set gnd_part_pins [list]
    
    # Get the vcc part pins
    set vcc_pins [get_pins -quiet -filter "(PARENT_CELL == [get_property NAME $rp_cell] && HD.ASSIGNED_PPLOCS == \"\" && DIRECTION == \"IN\")" -of_objects [get_nets <const1>]]
    
    if {[llength $vcc_pins] != 0} {
        # Add the names of the partition pins (from the RM's perspective) to the list
        set vcc_part_pins [get_property REF_PIN_NAME $vcc_pins]
    }
    
    # Get the gnd part pins
    set gnd_pins [get_pins -quiet -filter "(PARENT_CELL == [get_property NAME $rp_cell] && HD.ASSIGNED_PPLOCS == \"\" && DIRECTION == \"IN\")" -of_objects [get_nets <const0>]]
    
    if {[llength $gnd_pins] != 0} {
        # Add the names of the partition pins (from the RM's perspective) to the list
        set gnd_part_pins [get_property REF_PIN_NAME $gnd_pins]
    }
    
    ::tincr::print_list -header "VCC_PART_PINS" -channel $channel $vcc_part_pins
    ::tincr::print_list -header "GND_PART_PINS" -channel $channel $gnd_part_pins
}

## Searches through the given list of tiles, identifies used PIPs, and
# writes these used PIPs (as wires) to the PR static export file.
#
# @param tiles List of possible tiles with used PIPs (in a reconfigurable region)
# @param channel Output file handle
proc write_used_rp_wires { tiles static_nets channel } {
    set used_wires [list]
    
    # Get non partition-pin nets
    set nets [struct::set difference [get_nets -hierarchical] $static_nets]

    # Get wires from the PIPs. We only want the wires that are at the ends of nodes (not the in-between ones)
    # First get all nodes that are in the tiles we care about and that also have nets
    if {[llength $nets] != 0} {
        set nodes [::struct::set intersect [get_nodes -quiet -of_objects $nets] [get_nodes -quiet -of_objects $tiles]]
        
        if {[llength $nodes] != 0} {
            # Get the list of nets that those nodes deal with
            set nets [get_nets -of_objects $nodes]
            
            # Now, print out the PIPs of each tile using the list of tiles and the list of nets
            # TODO: Could probably make this faster with a map from tiles -> nets that go through that tile
            foreach tile $tiles {    
                set tile_pips [get_pips -quiet -filter "TILE == $tile" -of_objects $nets]
                foreach pip $tile_pips {
                    lappend used_wires "[get_wires -of_objects $pip]"
                }  
            }
        }
    }
        
    # print the used wires
    ::tincr::print_list -header "RESERVED_WIRES" -channel $channel $used_wires
}

## Prints the partial route strings for the partition pin routes.
# These route strings only contain the static portion of the nets.
#
# @param nets The nets to write route strings for
# @param channel output channel
# TODO: Optimize this procedure. 
proc write_static_routes { nets channel } {	
	foreach net $nets {
		if { ($net eq "<const0>") || ($net eq "<const1>") || ($net eq "const0") || ($net eq "const1")} {
		    continue
		}	
	
		# Get the name(s) of the port(s)
		# If the net connects to more than one partition pin, there will be multiple associated ports
	    set ports [get_pins -filter { HD.ASSIGNED_PPLOCS !=  "" } -of_objects [get_nets $net]]
		
		set portNames ""
		foreach port $ports {
			set portNames "$portNames [string replace $port 0 [string first "/" $port]]"
		}
		
		set route_string "STATIC_RT $net $portNames "
		
		# Split report_route_status by lines
		set lines [split [report_route_status -of_objects $net -return_string] "\n"]
		
		foreach line $lines {
			# Trim spaces, *'s, and p (partition pin marker)
			set line [string trim $line " *p"]
			
			# Remove characters starting from the first '(' to the end of the line
			# This is the PIP information
			set start_idx [string first "(" $line] 
			
			if {$start_idx == -1} {
				continue
			}
			
			set line [string replace $line $start_idx end]
			
			# Get rid of other extra characters
			set line [string trim $line " *\["]
			set line [string map {"p" ""} $line]
			set line [string map {"*" ""} $line]
			set line [string map {" " ""} $line]
			
			# Check if the first character is a closing curly brace
			set comparison [string compare -length 1 $line "\}"]
			
			if {$comparison == 0} {
				set line "$line \}"
				set line [string trimleft $line " \}*\[\]"]
			}
			
			# Check if the first character is an opening curly brace
			set comparison [string compare -length 1 $line "\{"]
			if {$comparison == 0} {
            	set cut_line [string trimleft $line " \{*\[\]"]
            	# Now check if the next character is a closing curly brace
            	set comparison [string compare -length 1 $cut_line "\}"]
                if {$comparison == 0} {
                	set line "\{ [string range $cut_line 1 end] \}"
                } else {
                	set line "\{ [string range $line 1 end]"
                }
			}
			append route_string "$line "
		}
		::tincr::print $channel $route_string			
	}
}

## Prints the static resources contained within a PR region in a static design.
#  Searches through a reconfigurable region and writes used resources.
#  (PIPs, site routethroughs) and partition pin information to the static resources file.
#  USAGE: tincr::write_static_resources [-quiet] [-verbose] static_dcp prRegion filename
#   
#  @param args Argument list shown in the usage statement above. 
#         The "-quiet " flag can be used to suppress console output. 
#         The "-verbose" flag can be used to print all messages to the console.
#         The required static_dcp parameter specifies the path to the DCP of the static design.
#         The required prRegion parameter specifies the name of the PR region cell.
#         The required routing_filename parameter specifies the path of the routing.rsc file.
#         The required static_filename parameter specifies the path of the static.rsc file.
#TODO: Remove duplicate logic (don't get all nets more than once, etc.)
proc ::tincr::write_static_resources { args } {
    set quiet 0
    set verbose 0
    set static_dcp ""
    set prRegion ""
    set routing_filename ""
    set static_filename ""

    ::tincr::parse_args {} {quiet verbose} {} {static_dcp prRegion routing_filename static_filename} $args
    
    set old_verbose $::tincr::verbose 
    if {$quiet} {
        set ::tincr::verbose 0
    } else {
        set ::tincr::verbose 1
    }
    
    open_checkpoint $static_dcp
    set rp_cell [get_cells $prRegion]
   
    # Write partition pins (to routing.rsc)
    set routing_filename [::tincr::add_extension ".rsc" $routing_filename]
    set routing_channel [open $routing_filename w]
	set partpin_time [tincr::report_runtime "::tincr::write_part_pins [subst -novariables {$routing_channel}]" s]
    ::tincr::print_verbose "Partition Pins Done...($partpin_time s)"
    
    # Write static partition pins (to routing.rsc)
	set static_partpin_time [tincr::report_runtime "write_static_part_pins [subst -novariables {$rp_cell $routing_channel}]" s]
    ::tincr::print_verbose "VCC/GND Partition Pins Done...($static_partpin_time s)"
    close $routing_channel
    
    # create the static resources file
    set static_filename [::tincr::add_extension ".rsc" $static_filename]
    set channel_out [open $static_filename w]
    
    # Print the static portion of partition pin routes
    set static_nets [get_nets -of_objects [get_cells -hierarchical -filter { IS_BLACKBOX == "TRUE" } ] ] 
    set static_route_time [tincr::report_runtime "write_static_routes [subst -novariables {$static_nets $channel_out}]" s]
    ::tincr::print_verbose "Static Routes Done...($static_route_time s)"

    # It is the user's responsibility to define the pblock for the PR region properly.
    # No checks are made to ensure it is valid. The partial device file should have the 
    # same boundaries as this pblock.
    set pblock [get_pblocks -of_objects $rp_cell]
    
    # Get the range of tiles in the pblock
    set tile_range [split [get_property GRID_RANGES $pblock] ":"]
    set bott_left_site [get_sites [lindex $tile_range 0]]
    set top_right_site [get_sites [lindex $tile_range 1]]
    set bott_left_tile [get_tiles -of_objects $bott_left_site]
    set top_right_tile [get_tiles -of_objects $top_right_site]
    
    # Get row and column ranges
    set max_row [get_property ROW $bott_left_tile]
    set min_row [get_property ROW $top_right_tile]
    set max_col [get_property COLUMN $top_right_tile]
    set min_col [get_property COLUMN $bott_left_tile]

    # Get used wires.
    # Get a list of tiles that might have used PIPs (CLB and INT)
    # Interconnect Tiles (INT_L, INT_R) and CLB Tiles (CLBLM_L, CLBLM_R, CLBLL_L, CLBLL_R) are possible types.
    set rp_tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col) && (TILE_TYPE == INT_L || TILE_TYPE == INT_R || TILE_TYPE == CLBLM_L || TILE_TYPE == CLBLM_R || TILE_TYPE == CLBLL_L || TILE_TYPE == CLBLL_R) "] 
    set used_wires_time [tincr::report_runtime "write_used_rp_wires [subst -novariables {$rp_tiles $static_nets $channel_out}]" s]
    ::tincr::print_verbose "Used Wires Done...($used_wires_time s)"
   
    # Get site route-throughs
    set tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col)"] 
    set routethrough_time [tincr::report_runtime "write_rp_site_routethroughs [subst -novariables {$tiles $channel_out}]" s]
    ::tincr::print_verbose "Site route-throughs Done...($routethrough_time s)"

    close_project
    close $channel_out
    set ::tincr::verbose $old_verbose
}
