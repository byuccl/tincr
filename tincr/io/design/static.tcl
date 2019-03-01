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
# static design export file.
#
# @param tiles List of tiles in the reconfigurable region (pblock)
# @param channel Output file handle
proc get_rp_site_routethroughs { tiles channel } {
    #TODO: Speed this procedure up. It is slow right now.
    set site_rts [list]
    set nets [get_nets -hierarchical]

    # Get all nodes that are in the tiles we care about and that also have nets
    set nodes [::struct::set intersect [get_nodes -quiet -of_objects $nets] [get_nodes -quiet -of_objects $tiles]]
    
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
            #set snk_pin [get_site_pins -of_object [get_nodes -downhill -of_object $pip]]
        #lappend site_rts "[get_sites -of_object $src_pin]([::tincr::site_pins get_info $src_pin name]-[::tincr::site_pins get_info $snk_pin name])" 
        lappend site_rts "[get_sites -of_object $src_pin]"
        }
        }
    }
    # print the site routethroughs to the pr static file
    ::tincr::print_list -header "SITE_RTS" -channel $channel $site_rts
}

# TODO: Migrate to tincr_checkpoints.tcl and output in placement.xdc for OOC checkpoints as well.
proc write_static_part_pins { rp_cell channel } {
    # The direction filter may be overkill
    # Assuming any pins in this lists will be VCC or GND part pins coming into the RP. Maybe do some checking here.
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
# writes these used PIPs to the PR static export file.
#
# @param tiles List of possible tiles with used PIPs (in a reconfigurable region)
# @param channel Output file handle
proc get_used_rp_wires { tiles channel } {
    set used_pips [list]
    set nets [get_nets -hierarchical]

    # Get all wires that are in the tiles we care about and that also have nets
    set wires [::struct::set intersect [get_wires -quiet -of_objects $nets] [get_wires -quiet -of_objects $tiles]]
    
    #TODO: Remove the wires that are part of partition pin routes from this list.
    
    # print the used wires to the pr static file
    ::tincr::print_list -header "RESERVED_WIRES" -channel $channel $wires
}

## Searches through the used sites in the reconfigurable region of the design, 
# identifies LUT BELs that are being used as either a routethrough or static 
# source (always outputs 1 or 0), and writes these BELs in the pr static export file.
#
# @param site_list List of <b>used</b> sites in the reconfigurable region.
# @param channel Output file handle
proc get_rp_static_and_routethrough_luts { tiles channel } {
    set vcc_sources [list]
    set gnd_sources [list]
    set routethrough_luts [list]
    set MAX_CONFIG_SIZE 20
    
    # get list of used sites within the reconfigurable region.
    set site_list [get_sites -quiet -filter IS_USED -of_objects $tiles] 
    
    foreach bel [get_bels -quiet -of $site_list -filter {TYPE =~ *LUT* && !IS_USED}] {
    
    set config [get_property CONFIG.EQN $bel]
    
    # skip long config strings...they cannot be static sources or routethroughs
    if { [string length $config] > $MAX_CONFIG_SIZE } {
        continue
    }
    
    if { [regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(?1\)? ?} $config -> pin] } { ; # VCC source
        lappend vcc_sources "[get_property NAME $bel]/$pin"
    } elseif { [regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(?0\)? ?} $config -> pin] } { ; # GND source
        lappend gnd_sources "[get_property NAME $bel]/$pin"
    } elseif { [regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(+(A[1-6])\)+ ?} $config -> outpin inpin] } { ; # LUT routethrough
        lappend routethrough_luts "$bel/$inpin/$outpin"
    }
    }
    
    # In some cases, FFs that are configured as Latches can be used with no cell being placed on the
    # corresponding Flip Flip. Look for this and add them to the routethrough list. (D and Q are always the input/output pin)
    foreach bel [get_bels -quiet -of $site_list -filter {NAME=~*FF* && !IS_USED}] {
    set mode [string trim [get_property CONFIG.LATCH_OR_FF $bel]]
    if {$mode == "LATCH"} {
        lappend routethrough_luts "$bel/D/Q"
    }
    }
    
    # print the gnd sources, vcc sources, and lut routethroughs to the pr static file
    ::tincr::print_list -header "VCC_SOURCES" -channel $channel $vcc_sources
    ::tincr::print_list -header "GND_SOURCES" -channel $channel $gnd_sources
    ::tincr::print_list -header "LUT_RTS" -channel $channel $routethrough_luts
}

##
proc get_static_routes { nets channel } {	
	foreach net $nets {
	
		if { ($net eq "<const0>") || ($net eq "<const1>") || ($net eq "const0") || ($net eq "const1")} {
		    continue
		}	
	
		# Get the name(s) of the port(s)
		# If the net connects to more than one partition pin, there will be multiple associated ports
	    set ports [get_pins -filter { HD.ASSIGNED_PPLOCS !=  "" } -of_objects [get_nets $net]]
		
		# TODO: There is almost definitely a better way to do this part.
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
            	# I'm sure there is a more effieicnt way of doing this
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
		#puts $route_string
		::tincr::print $channel $route_string
		#lappend static_routes $route_string
			
	}
}


## Prints the static resources for every PR region (specified as pblocks) in a static design.
#  Searches through a reconfigurable region (a pblock) and writes used resources
#  (PIPs, site routethroughs) and partition pin information to the static resources file.
#  USAGE: tincr::write_static_resources [-quiet] [-verbose] static_dcp pblock filename
#   
#  @param args Argument list shown in the usage statement above. 
#         The "-quiet " flag can be used to suppress console output. 
#         The "-verbose" flag can be used to print all messages to the console.
#         The required static_dcp parameter specifies the path to the DCP of the static design.
#         The required pblock parameter specifies the pblock for the PR region.
#         The required filename parameter specifies
#TODO: Remove duplicate logic (don't get all nets more than once, etc.)
#TODO: Instead of passing the pblock, just pass the name of the RP cell. Then get the pblock from the cell.
proc ::tincr::write_static_resources { args } {
    set quiet 0
    set verbose 0
    set static_dcp ""
    set pblock ""
    set placement_filename ""
    set static_filename ""

    ::tincr::parse_args {} {quiet verbose} {} {static_dcp pblock placement_filename static_filename} $args
    
    set old_verbose $::tincr::verbose 
    if {$quiet} {
        set ::tincr::verbose 0
    } else {
        set ::tincr::verbose 1
    }
    
    open_checkpoint $static_dcp
    
    set pblock [get_pblocks $pblock]
    
    
    # Get partition pins (OOC ports) and write them to the placement.rsc file
    
    # Open the placement.rsc for appending
    set placement_filename [::tincr::add_extension ".rsc" $placement_filename]
    set placement_channel [open $placement_filename a]
    
    set rp_cell [get_cells -of_objects $pblock]
    
    #TODO: Measure this again.
    
	set diff_time [tincr::report_runtime "::tincr::write_part_pins [subst -novariables {$placement_channel}]" s]
	set diff_time [tincr::report_runtime "write_static_part_pins [subst -novariables {$rp_cell $placement_channel}]" s]
	::tincr::print_verbose "Wrote static partition pins...($diff_time seconds)"   
    close $placement_channel
    
    # create the static file
    set static_filename [::tincr::add_extension ".rsc" $static_filename]
    set channel_out [open $static_filename w]
    
    # It is the user's responsibility to define the pblock for the PR region properly.
    # No checks are made to ensure it is valid. The partial device file should have the 
    # same boundaries as this pblock.
    set tile_range [split [get_property GRID_RANGES $pblock] ":"]
    set bott_left_site [get_sites [lindex $tile_range 0]]
    set top_right_site [get_sites [lindex $tile_range 1]]
    
    # Get the range of tiles in the pblock
    set bott_left_tile [get_tiles -of_objects $bott_left_site]
    set top_right_tile [get_tiles -of_objects $top_right_site]
    
    # Get row and column ranges
    set max_row [get_property ROW $bott_left_tile]
    set min_row [get_property ROW $top_right_tile]
    set max_col [get_property COLUMN $top_right_tile]
    set min_col [get_property COLUMN $bott_left_tile]
    
    ::tincr::print_verbose "Pblock Tile Range: Rows $min_row - $max_row, Columns $min_col - $max_col"
        
    # Get used PIPs.
    # Get a list of tiles that might have used PIPs (CLB and INT)
    # Interconnect Tiles (INT_L, INT_R) and CLB Tiles (CLBLM_L, CLBLM_R, CLBLL_L, CLBLL_R)
    # are possible types.
    set rp_tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col) && (TILE_TYPE == INT_L || TILE_TYPE == INT_R || TILE_TYPE == CLBLM_L || TILE_TYPE == CLBLM_R || TILE_TYPE == CLBLL_L || TILE_TYPE == CLBLL_R) "] 
    set diff_time [tincr::report_runtime "get_used_rp_wires [subst -novariables {$rp_tiles $channel_out}]" s]
    ::tincr::print_verbose "Found used PIPs...($diff_time seconds)"
   
    # Get site route-throughs
    set tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col)"] 
    set diff_time [tincr::report_runtime "get_rp_site_routethroughs [subst -novariables {$tiles $channel_out}]" s]
    ::tincr::print_verbose "Found site route-throughs...($diff_time seconds)"
    
    # Get complete static routes
    # It is important for these to come first on the RS2 side.
    set static_nets [get_nets -of_objects [get_cells -hierarchical -filter { IS_BLACKBOX == "TRUE" } ] ] 
    set diff_time [tincr::report_runtime "get_static_routes [subst -novariables {$static_nets $channel_out}]" s]
	::tincr::print_verbose "Found static portions of nets...($diff_time seconds)"
    

    
    close_project
    close $channel_out
    set ::tincr::verbose $old_verbose
    
    
    # Static or routethrough LUT BELs should never be used by the static design because no static logic will
    # be placed in PR regions. 
    # Get static and routethrough LUT BELs.
    # Get used sites within the reconfigurable region.
    # TODO: Don't duplicate the get_rp_static_and_routethrough_luts process.
    #
    #set site_list [get_sites -quiet -filter IS_USED -of_objects $tiles] 
    #set diff_time [tincr::report_runtime "get_rp_static_and_routethrough_luts [subst -novariables {$site_list $channel_out}]" s]
    #::tincr::print_verbose "Found static & route-through LUTs...($diff_time seconds)"
}


