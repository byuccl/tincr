package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
	get_used_resources \
	get_tile_pips \
	get_site_routethroughs \
	write_static_and_routethrough_luts
}

# Can optimize this a bit.
#proc get_pblock_tile_range { } {
#    # Depending on the pblock's GRIDTYPES property, multiple ranges 
#    # of different types of sites may be included in GRID_TYPES. 
#    set bott_left_sites [list]
#    set top_right_sites [list]
#	
#    set ranges [split [get_property GRID_RANGES $pblock] ", "]
#	
#    foreach site_range $ranges {
#	set split_range [split [get_property GRID_RANGES $pblock] ":"]
#        lappend bott_left_sites [get_sites [lindex $split_range 0]]
#	lappend top_right_sites [get_sites [lindex $split_range 1]]
#	 
#    }
#	
#    # Choose the largest range
#    set bott_left_tile [get_tiles -of_objects [lindex $bott_left_sites 0]]
#    set top_right_tile [get_tiles -of_objects [lindex $top_right_sites 0]]
#	
#	
#    foreach site $bott_left_sites {
#	    
#    }
#    
#}

proc ::tincr::get_used_resources { pblock } {
    # create the static file
    set filename "pr_static"
    set filename [::tincr::add_extension ".rsc" $filename]
    set channel_out [open $filename w]
	
    # get a list of all the tiles in the pblock
    # Question: What is the difference between DERIVED_RANGES and GRID_RANGES?
    # GRID_RANGES is the range of the PBLOCK you have explicitly defined, i.e. SLICE_X6Y50:SLICE_X13Y99
    # DERIVED_RANGES is different from GRID_RANGES when SNAPPING_MODE is on.
    # Snapping mode adjusts the edges of the block, possibly making it taller and wider.
    # The original pblock is preserved, but these adjustments are saved so the pblock conforms to PR rules.
    # The derived ranges reflects this range.
    # Ex: RAMB36_X0Y10:RAMB36_X0Y19, RAMB18_X0Y20:RAMB18_X0Y39, DSP48_X0Y20:DSP48_X0Y39, SLICE_X8Y50:SLICE_X11Y99
    # For now, I will assume the user will define the pblock properly in the first place and that he will use
    # this pblock for his partial device. So I will use GRID_RANGES. 
    # Note that grid ranges will include more than the recongiruable area if the pblock is not properly set up
    # by the user (so snapping mode actually has to make fixes).
    # Get the range of sites in the pblock
	# When SNAPPING_MODE is set to a value 
	#of ON or ROUTING, it creates a new set of derived Pblock ranges that are used for 
	#implementation.
	# If snapping mode is off, DERIVED_RANGES == GRID_RANGES
	# Pblock ranges must only include types SLICE, RAMB18, RAMB36, and DSP48 resource types.
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
	
    # Get site rouethroughs
    get_site_routethroughs $tiles $channel_out
	
    close $channel_out
}

# In a site route-through, a net is passed in through one
# of a site's input pins, routed through the site's internal routing structure,
# and passed out through one of the site's output pins.\
# Once a single site route-through has been made, the entiire site is classified as a routing resource,
# making it illegal to place any cells on it.
# Site route-throughs are represented by PIP objects, with their IS_PSEUDO property set to 1.	
# Excluded PIPs can't be used for routing.
# Test PIPs are only usable by the vendor

# Note that sites that are being used as route-throughs are NOT marked as used by Vivado.

# Question: When is IS_SITE_PIP even true?
# true when a PIP is inside a site and is used for internal site structure
# It seems like we call routing BELs site PIPs, but Vivado has a concept
# of site pips that are a subset of PIPs.
	
proc ::tincr::get_site_routethroughs { tiles channel } {

    # Get a subset of the PIPs that are within the tiles we care about 
    # and that are used in nets.
    # If tiles is a very largew list, it's faster to just use net_pips.
    set tile_pips [lsort [get_pips -quiet -of_objects $tiles -filter {!IS_TEST_PIP && !IS_EXCLUDED_PIP}]]
    set net_pips [lsort [get_pips -quiet -of_objects [get_nets -hierarchical] -filter {!IS_TEST_PIP && !IS_EXCLUDED_PIP}]]
    set pips [::struct::set intersect $tile_pips $net_pips]

    foreach pip $pips {
	set uphill_node [get_nodes -quiet -uphill -of_object $pip]
	set downhill_node [get_nodes -quiet -downhill -of_object $pip]
	
	if {$uphill_node != "" && $downhill_node != ""} {
            # If PSEUDO, it's a route-through PIP.
            if {[get_property IS_PSEUDO $pip]} {
                set src_pin [get_site_pins -of_object [get_nodes -uphill -of_object $pip]]
                set snk_pin [get_site_pins -of_object [get_nodes -downhill -of_object $pip]]
                puts $channel "SITE_ROUTETHROUGH: [get_sites -of_object $src_pin]([::tincr::site_pins get_info $src_pin name]-[::tincr::site_pins get_info $snk_pin name])"
	    }
        }
    }
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
	    puts $channel ""
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