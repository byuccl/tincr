package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        write_tcp \
        read_tcp \
        write_design_info \
        write_placement_xdc \
        write_routing_xdc \
        get_design_info \
        get_pins_to_lock\
        write_placement_rs2\
        write_routing_rs2 \
        write_rscp \
        write_tcp_for_pblock \
        write_tcp_ooc_test
}

# TODO Create bulleted list of the files in a TCP
## Writes a Tincr checkpoint to file. A Tincr checkpoint is able to store a basic design, its placement, and routing in a human-readble format. consists of five files: an EDIF netlist representation and XDC files that constrain the placement and routing of the design. Currently, designs with route-throughs are not supported, though this functionality is planned for a future release of Tincr.
# @param filename The path and filename where the Tincr checkpoint is to be written.

proc ::tincr::read_tcp_ooc_test {filename} {

    set tcp_files [glob "$filename[file separator]*.tcp"]

    if {$tcp_files == ""} {
        puts "[Error] No Tcp files found in the specified directory"
        return
    }

    set part [get_property PART [get_design]]

    foreach tcp $tcp_files {
        link_design -mode out_of_context -part $part -name $tcp
        read_tcp -quiet $tcp
        write_checkpoint -force "$filename[file separator]_$tcp.dcp"
        remove_files *
        close_design
    }
}

proc ::tincr::write_tcp_ooc_test {filename} {

    file mkdir $filename

    foreach pblock [group_cells_by_clock_region] {
        set outfile "$filename[file separator][get_property NAME $pblock].tcp"

        set nets [get_internal_nets $pblock]
        set internal_nets [lindex $nets 0]
        set external_nets [lindex $nets 1]

        write_tcp_for_pblock $outfile $pblock $internal_nets
    }
}

proc ::tincr::write_tcp_for_pblock {filename pblock nets} {
    set filename [::tincr::add_extension ".tcp" $filename]

    file mkdir $filename

    write_edif -force -pblock $pblock "${filename}"
    write_placement_xdc -cells [get_cells -of $pblock] "${filename}/placement.xdc"
    write_routing_xdc -sites [get_sites -of $pblock -filter IS_USED] -nets $nets -global_logic "${filename}/routing.xdc"
}

proc ::tincr::write_tcp {filename} {
    set filename [::tincr::add_extension ".tcp" $filename]

    file mkdir $filename

    # TODO Planned feature: Remove route-throughs.

    write_design_info "${filename}/design.info"
    write_edif -force "${filename}/netlist.edf"
    write_xdc -force "${filename}/constraints.xdc"
    write_placement_xdc "${filename}/placement.xdc"
    write_routing_xdc -global_logic "${filename}/routing.xdc"

}

# Creates a RapidSmith2 checkpoint directory to load designs into RapidSmith
# Should I modify the extension to ".rscp" instead?
proc ::tincr::write_rscp {filename} {
    set filename [::tincr::add_extension ".tcp" $filename]
    file mkdir $filename

    puts "Writing RapidSmith2 checkpoint to $filename..."

    write_design_info "${filename}/design.info"
    write_edif -force "${filename}/netlist.edf"
    write_xdc -force "${filename}/constraints.rsc"
    write_placement_rs2 "${filename}/placement.rsc"
    write_routing_rs2 -global_logic "${filename}/routing.rsc"

    puts "Successfully Created RapidSmith2 Checkpoint!"
}

proc ::tincr::read_tcp {args} {
    set quiet 0
    set verbose 0
    ::tincr::parse_args {} {quiet verbose} {} {filename} $args

    set q "-quiet"
    set ::tincr::verbose 1
 
    # quiet has priority over verbose if both are specified
    if {$quiet} {
        set ::tincr::verbose 0        
    } elseif {$verbose} {
        set q "-verbose"
    }
       
    set filename [::tincr::add_extension ".tcp" $filename]

    ::tincr::print_verbose "Parsing device information file..." 
    set part [get_design_info "$filename" part]

    # NOTE: The edif must be read in before the design is linked, but the other files do not have to be
    ::tincr::print_verbose "Reading netlist..."
    set edif_runtime [report_runtime "read_edif $q ${filename}/netlist.edf" s]
    ::tincr::print_verbose "Netlist added successfully. ($edif_runtime seconds)"

    ::tincr::print_verbose "Linking design..."
    set link_runtime [report_runtime "link_design $q -part $part" s]
    ::tincr::print_verbose "Design linked successfully. ($link_runtime seconds)"

    # Disabling placement checks
    # set placer_checks [get_drc_ruledecks placer_checks]
    # set_property IS_ENABLED 0 $placer_checks

    ::tincr::print_verbose "Reading design constraints..."
    set constraint_runtime [report_runtime "read_xdc $q -no_add ${filename}/constraints.xdc" s]
    ::tincr::print_verbose "Design constraints added successfully. ($constraint_runtime seconds)"

    ::tincr::print_verbose "Reading placement constraints..."
    set place_runtime [report_runtime "read_xdc $q -no_add ${filename}/placement.xdc" s]
    ::tincr::print_verbose "Placement constraints added successfully. ($place_runtime seconds)"

    ::tincr::print_verbose "Reading routing constraints..."
    set route_runtime [report_runtime "read_xdc $q -no_add ${filename}/routing.xdc" s]
    ::tincr::print_verbose "Routing constraints added successfully. ($route_runtime seconds)"

    # Compute the total runtime
    set total_runtime [expr { $edif_runtime + $link_runtime + $constraint_runtime + $place_runtime + $route_runtime } ]

    #set space "        "
    #puts $outfile "|   read_edif   |   link_design   |   constraints   |   placement.xdc   |   routing.xdc   |   # of nets   |   # of cells   |   total run time"
    #puts $outfile "-----------------------------------------------------------------------------------------------------------------------------------------------"
    #puts $outfile "    $edif_runtime $space $link_runtime $space $constraint_runtime $space $place_runtime  $space $route_runtime\
    #          	  $space[llength [get_nets -hierarchical]]  $space  [llength [get_cells -hierarchical]]  $space$total_runtime s"
    #close $outfile

    # Unlock the design ... is this necessary?
    ::tincr::print_verbose "Unlocking the design..."
    lock_design $q -level placement -unlock

    # this may work for importing designs...need to test using a design diff function...which TINCR has!
    # need to test with a custom routed design that uses a different input pin for the bel route-through
    # possible hack to complete nets that use a BEL route-through
    # foreach net [get_nets $q -filter {ROUTE_STATUS==ANTENNAS}] {
    #	route_design -nets -directive Quick $net -quiet
    # }

    # unlock the design at the end of the import process...do we need to do this?
    ::tincr::print_verbose "Design importation complete. ($total_runtime seconds)"

    remove_files -quiet *
    return {$edif_runtime $link_runtime $constraint_runtime $place_runtime $route_runtime $total_runtime}
}

# TODO: When filtering through cells in sites should we use the PRIMITIVE_LEVEL==LEAF if our search?
# 		or can we ignore it?
proc ::tincr::sort_cells_for_export { cells } {

    set primitives [list]
    set luts [list]
    set carrys [list]
    set ff [list]
    set ff_5 [list]

    # TODO: Eventually, we may have to look through all of the cells
    #		(internal cells of macros) to support macros.
    foreach cell $cells {
        if {[cells is_placed $cell]} {
            set group [get_property PRIMITIVE_GROUP $cell]
            if {$group == "LUT"} {
                lappend luts $cell
            } elseif {$group == "CARRY"} {
                lappend carrys $cell
            } elseif {$group == "FLOP_LATCH"} {
                if {[string first "5" [get_property BEL $cell]] == -1} {
                    lappend ff $cell
                } else {
                    lappend ff_5 $cell
                }
            } else {
                lappend primitives $cell
            }
        }
    }

    return [concat $primitives $luts $ff $carrys $ff_5]
}

proc ::tincr::write_design_info {args} {
    ::tincr::parse_args {} {} {} {filename} $args

    set filename [::tincr::add_extension ".info" $filename]

    set outfile [open $filename w]

    puts $outfile "part=[get_property PART [current_design]]"
    #    puts $outfile [get_property TOP [current_design]]

    close $outfile
}

proc ::tincr::write_placement_xdc {args} {
    ::tincr::parse_args {cells} {} {} {filename} $args

    set filename [::tincr::add_extension ".xdc" $filename]

    set xdc [open $filename w]

    #set f2 [::tincr::add_extension ".txt" $filename]
    #set carry_xdc [open $f2 w]

    #shouldn't this be in the constraints file? I guess it needs to be here actually
    foreach port [get_ports] {
        if {[get_property PACKAGE_PIN $port] != ""} {
            puts $xdc "set_property PACKAGE_PIN [get_property PACKAGE_PIN $port] \[get_ports \{[get_name $port]\}\]"
        }
    }

    # if the cells option is not provided, do all cells
    if {[catch {$cells == ""}]} {
        set cells [get_cells -hierarchical -filter {PRIMITIVE_LEVEL!=INTERNAL}]
    }

    foreach cell [sort_cells_for_export $cells] {

        # ASSUMPTION: I am assuming that the only macros that are un-flattenable are LUT RAMS
        # Also, through experimentation, it looks like only one LUT RAM can be placed on a site at a time
        # so we don't have to worry about ordering distributed rams
        if { [get_property PRIMITIVE_LEVEL $cell] == "MACRO" } {
            puts "Warning: There is an unflattened macro in the design...this is currently not supported with RapidSmith2"
            puts $xdc "set_property LOC [get_property LOC $cell] \[get_cells \{[get_name $cell]\}\]"
        } else {
            puts $xdc "set_property BEL [get_property BEL $cell] \[get_cells \{[get_name $cell]\}\]"
            puts $xdc "set_property LOC [get_property LOC $cell] \[get_cells \{[get_name $cell]\}\]"

            set pins_to_lock [get_pins_to_lock $cell]
            if {[llength $pins_to_lock] != 0} {
                puts $xdc "set_property LOCK_PINS \{$pins_to_lock\} \[get_cells \{[get_name $cell]\}\]"
            }
        }
    }

    close $xdc
}

proc ::tincr::write_routing_xdc {args} {
    set global_logic 0
    ::tincr::parse_args {nets sites} {global_logic} {} {filename} $args

    set filename [::tincr::add_extension ".xdc" $filename]

    set xdc [open $filename w]

    if {[catch {$sites == ""}]} {
        set sites [get_sites -quiet -filter IS_USED]
    }

    foreach site $sites {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]

        # The SITE_TYPE property of a site is unreliable. To determine the actual site type
        # that is being used...use the BEL property of any cell in the site...we can probably
        # update this code once/if this bug is fixed.
        set sample_cell [lindex [get_cells -of $site] 0]
        #set site_type [get_property SITE_TYPE $site]
        set site_type [lindex [split [get_property BEL $sample_cell] "."] 0]

        # TODO: We needed to add a special case for IOB33 since it causes Vivado to crash...update once this gets fixed
        if {$site_pips != "" && $site_type != "IOB33"} {
            puts $xdc "set_property MANUAL_ROUTING $site_type \[get_sites \{[get_property NAME $site]\}\]"
            puts $xdc "set_property SITE_PIPS \{$site_pips\} \[get_sites \{[get_property NAME $site]\}\]"
        }
    }

    # TODO: Do we want to export partially routed nets as well? This may be useful, but its unclear how useful

    if {[catch {$nets == ""}]} {
        if {$global_logic} {
            set nets [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == ROUTED}]
        } else {
            set nets [get_nets -quiet -hierarchical -filter {TYPE != POWER && TYPE != GROUND && ROUTE_STATUS == ROUTED}]
        }
    }

    #TODO: may be faster to filter the nets originally by by type, and process the GND and VCC nets differently than the regular nets
    foreach net $nets {
        set route_string [get_property ROUTE $net]
        # special case for VCC nets
        if { [get_property TYPE $net] == "POWER" || [get_property TYPE $net] == "GROUND" } {
            set tiles [get_tiles -of $net]
            if {[llength $tiles] == 2} {
                # assuming that the second tile in the tile list is the interconnect tile
                set switchbox_tile [lindex $tiles 1]
                set route_string [string range [get_property ROUTE $net] 3 end-3]
                set route_string "\{ $switchbox_tile/$route_string \}"
            } else {
                set route_string "\{$route_string\}"
            }
        }

        puts $xdc "set_property ROUTE $route_string \[get_nets \{[get_property NAME $net]\}\]"
        #        puts $xdc "device::direct_route -route \{[get_property ROUTE $net]\} \[get_nets \{[get_property NAME $net]\}\]"
    }

    close $xdc
}

proc ::tincr::get_design_info {args} {
    ::tincr::parse_args {} {} {} {filename info} $args

    set filename [::tincr::add_extension ".tcp" $filename]

    set infile [open "${filename}/design.info" r]
    set lines [split [read $infile] "\n"]
    close $infile

    foreach line $lines {
        if {[regexp {^([^=]+)=(.+)$} $line matched key value]} {
            if {$key == $info} {
                return $value
            }
        }
    }

    return ""
}

proc ::tincr::get_pins_to_lock {cell} {
    set group [get_property PRIMITIVE_GROUP $cell]
    set pins_to_lock [list]
    if {$group == "LUT" || $group == "INV" || $group == "BUF"} {
        foreach pin [get_pins -of_object $cell -filter {DIRECTION == IN}] {
            set bel_pin [get_bel_pins -quiet -of_object $pin]

            if {$bel_pin != ""} {
                #TODO These get_*_info commands should be deprecated
                lappend pins_to_lock "[::tincr::pins::info $pin name]:[::tincr::bel_pins::get_info $bel_pin name]"
            }
        }
    }
    return $pins_to_lock
}

proc ::tincr::write_placement_rs2 {filename} {

    set filename [::tincr::add_extension ".rsc" $filename]
    set txt [open $filename w]

    #right now RS2 doesn't support top-level ports, but we may need this in the future
    foreach port [get_ports] {
        if {[get_property PACKAGE_PIN $port] != ""} {
            puts $txt "PACKAGE_PIN [get_property PACKAGE_PIN $port] [get_ports [get_name $port]]"
        }
    }

    set cells [get_cells -hierarchical -filter {PRIMITIVE_LEVEL!=INTERNAL}]

    # TODO: update this when macros get supported...currently only supports leaf cells
    foreach cell [sort_cells_for_export $cells] {
        if { [get_property PRIMITIVE_LEVEL $cell] == "LEAF"} {
            set sitename [get_property LOC $cell]
            set site [get_sites $sitename]
            #For Bonded PAD sites, the XDLRC uses the package pin name rather than the actual sitename
            if {[get_property IS_PAD $site] == 1} {
                if {[get_property IS_BONDED $site]} {
                    set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
                }
            }

            set bel [lindex [split [get_property BEL $cell] "."] end]

            #NOTE: We have to do this, because the SITE_TYPE property of sites are not updated correctly
            #	   when you place cells there. BUFG is an example
            set sitetype [lindex [split [get_property BEL $cell] "."] 0]

            set tile [get_tile -of $site]

            puts $txt "LOC [get_name $cell] $sitename $sitetype $bel $tile"

            #print the pin mappings for LUT cells
            set pins_to_lock [get_pins_to_lock $cell]
            if {[llength $pins_to_lock] != 0 } {
                puts $txt "LOCK_PINS $pins_to_lock [get_cells [get_name $cell]]"
            }
        }
    }

    close $txt
}

#TODO: Update this once we have a better idea of what we will need for RS2 in terms of routing.
#TODO: Add a suffix function to the TCL util package
proc ::tincr::write_routing_rs2 {args} {
    set global_logic 0
    ::tincr::parse_args {} {global_logic} {} {filename} $args

    # create the routing file
    set filename [::tincr::add_extension ".rsc" $filename]
    set txt [open $filename w]

    foreach site [get_sites -quiet -filter IS_USED] {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]

        if {$site_pips != ""} {

            set sitename [get_property NAME $site]

            if { [get_property IS_PAD $site] && [get_property IS_BONDED $site] } {
                set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
            }

            puts -nonewline $txt "SITE_PIPS $sitename "

            foreach sp $site_pips {
                puts -nonewline $txt "[lindex [split $sp "/"] end] "
            }
            puts $txt ""
        }
    }

    # TODO: add support for partially routed nets
    if {$global_logic} {
    	set nets [get_nets -quiet -hierarchical]
    } else {
    	set nets [get_nets -quiet -hierarchical -filter {TYPE != POWER && TYPE != GROUND}]
    }

    foreach net $nets {

        set status [get_property ROUTE_STATUS $net]

        if {$status == "INTRASITE"} {
            puts $txt "INTRASITE [get_property NAME $net]"
        } elseif {$status == "ROUTED"} {

            puts $txt "INTERSITE [get_property NAME $net] [get_site_pins -of $net]"

            set route_string [get_property ROUTE $net]
            set type [get_property TYPE $net]

            # Special case for VCC/GND nets with only a single source.
            # Inserts the tile of the source TIEOFF into the ROUTE string.
            # This is necessary because otherwise the ROUTE string is ambiguous
            # Example :  { VCC_WIRE IMUX_L15 IOI_OLOGIC0_T1 LIOI_OLOGIC0_TQ LIOI_T0 } 
            # becomes -> { INT_L_X0Y54/VCC_WIRE IMUX_L15 IOI_OLOGIC0_T1 LIOI_OLOGIC0_TQ LIOI_T0 }
            if { $type == "POWER" || $type == "GROUND" } {
                set tiles [get_tiles -of $net]
                if {[llength $tiles] == 2} {
                    # assuming that the second tile in the tile list is the interconnect tile
                    set switchbox_tile [lindex $tiles 1]
                    set route_string [string range [get_property ROUTE $net] 3 end-3]
                    set route_string "( \{ $switchbox_tile/$route_string \} )"
                }
            }

            puts $txt "ROUTE [get_property NAME $net] $route_string"
        }
    }

    close $txt
}

# packages the nets of the given pblock by internal nets,
# and boundary nets. A list of list of nets is returned.
# The first object is the internal nets to the pblock,
# and the second object is the boundary nets of the pblock
proc ::tincr::get_internal_nets { pblock } {

    set nets [list]
    set internal_nets [list]
    set boundary_nets [list]

    set cells [get_cells -of $pblock]

    #create a set of cells that are in the pblock
    ::struct::set add cell_set $cells

    # go through each net in the pblock, and place them into bins
    foreach net [get_nets -of $cells] {
        set net_is_internal 1
        foreach cell [get_cells -of $net] {
            if { ![::struct::set contains $cell_set $cell] } {
                set net_is_internal 0
                break
            }
        }

        if { $net_is_internal } {
            lappend internal_nets $net
        } else {
            lappend boundary_nets $net
        }
    }

    lappend nets $internal_nets
    lappend nets $boundary_nets

    return nets
}

# groups cells by clock domains, and returns a pblock for each domain
proc ::tincr::group_cells_by_clock_region { } {
    set i 0
    set pblock_list [list]

    foreach region [get_clock_regions] {
        # filter out I/O cells...
        set cells [get_cells -of $region -filter {PRIMITIVE_TYPE!~IO.*} -quiet]

        # empty list...skip
        if { $cells == "" } {
            continue;
        }

        set pblock [create_pblock "p$i"]

        add_cells_to_pblock $pblock $cells

        set tiles [get_tiles -of $region]
        set corner_one [get_leftmost_slice [get_closest_clb_tile [lindex $tiles 0] 0]]
        set corner_two [get_rightmost_slice [get_closest_clb_tile [lindex $tiles end] 1]]

        resize_pblock -add "$corner_one:$corner_two" $pblock

        lappend pblock_list $pblock
        incr i
    }

    return $pblock_list;
}

# Function used to get the CLB tile that is closest to the specified tile in the
# specified direction. Currently not doing any error checking. Will have
# to do this to make it more general.
proc ::tincr::get_closest_clb_tile { tile {direction 0} } {

    set row [get_property ROW $tile]
    set column [get_property COLUMN $tile]
    set tiles_in_row [get_tiles -filter ROW==$row]

    while { ![string match CLB* [get_property TILE_TYPE $tile]] } {
        if { $direction == 0 } {
            incr column
        } else {
            incr column -1
        }

        set tile [lindex $tiles_in_row $column]
    }

    return $tile
}

# assuming that the first slice in the list is the rightmost
proc ::tincr::get_leftmost_slice { clb } {
    return [lindex [get_sites -of $clb] 1]
}

proc ::tincr::get_rightmost_slice { clb } {
    return [lindex [get_sites -of $clb] 0]
}

proc ::tincr::is_clb_tile { tile } {
    return [string match CLB* [get_property TILE_TYPE $tile]]
}
