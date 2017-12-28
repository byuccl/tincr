package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
	get_used_resources \
	get_tile_pips \
	write_static_and_routethrough_luts
}

proc ::tincr::get_used_resources { pblock } {
    # create the static file
    set filename "pr_static"
    set filename [::tincr::add_extension ".rsc" $filename]
    set channel_out [open $filename w]
	
    # get a list of all the tiles in the pblock
    # Question: What is the difference between DERIVED_RANGES and GRID_RANGES
    
    # Get the range of sites in the pblock
    set tile_range [split [get_property DERIVED_RANGES $pblock] ":"]
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
    
    ::tincr::print_verbose "Pblock Block Tile Range: Rows $min_row - $max_row, Columns $min_col - $max_col"
	    
    # Get all CLB and INT tiles within the pblock.
    # Get a list of tiles that might have used PIPs.
    # Interconnect Tiles (INT_L, INT_R) and CLB Tiles (CLBLM_L, CLBLM_R, CLBLL_L, CLBLL_R)
    # are possible types.
    # QUESTION: Is this a complete list of possible tile types with switchboxes?
    set pip_tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col) && (TILE_TYPE == INT_L || TILE_TYPE == INT_R || TILE_TYPE == CLBLM_L || TILE_TYPE == CLBLM_R || TILE_TYPE == CLBLL_L || TILE_TYPE == CLBLL_R) "] 
    get_tile_pips $pip_tiles $channel_out
	
    # Now, get static and routethrough LUT BELs
    set tiles [get_tiles -filter "(ROW >= $min_row && ROW <= $max_row && COLUMN <= $max_col && COLUMN >= $min_col)"] 
    write_static_and_routethrough_luts $tiles $channel_out
	
    close $channel_out
}


# There may be some ways to optimize this some more.
proc ::tincr::get_tile_pips { tiles channel } {
    set nets [get_nets -hierarchical]

    # Get all nodes that are in the tiles we care about and that also have nets
    set nodes [::struct::set intersect [get_nodes -quiet -of_objects $nets] [get_nodes -quiet -of_objects $tiles]]
	
    # Get the list of nets that those nodes deal with
    set nets [get_nets -of_objects $nodes]
	
    # Now, print out the PIPs of each tile using the list of tiles and the list of nets
    # TODO: Could probably make this faster with a map from tiles -> nets that go through that tile
    foreach tile $tiles {    
	# If I just use -of_objects $nodes, I will probably find the weird VCC PIPs too. (physical nets)
	set tile_pips [get_pips -quiet -filter "TILE == $tile" -of_objects $nets]
	
	if {[llength $tile_pips] > 0 } {
	    puts -nonewline $channel "$tile: " 		
	    
	    foreach pip $tile_pips {
		puts -nonewline $channel "[get_property NAME $pip] " 		
	    }
	    puts ""
	}           
    }
}

## Searches through the used sites in the reconfigurable region of the design, 
# identifies LUT BELs that are being used as either a routethrough or static 
# source (always outputs 1 or 0), and writes these BELs in the pr static export file.
#
# @param tiles List of tiles in the reconfigurable region of the design
# @param channel Output file handle
proc write_static_and_routethrough_luts { tiles channel } {
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