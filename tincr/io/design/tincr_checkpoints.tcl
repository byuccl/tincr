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
        write_rscp       
}

# TODO Create bulleted list of the files in a TCP
## Writes a Tincr checkpoint to file. A Tincr checkpoint is able to store a basic design, its placement, and routing in a human-readble format. consists of five files: an EDIF netlist representation and XDC files that constrain the placement and routing of the design. Currently, designs with route-throughs are not supported, though this functionality is planned for a future release of Tincr.
# @param filename The path and filename where the Tincr checkpoint is to be written.

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
    write_placement_rs2 "${filename}/placement.txt"
    write_routing_rs2 -global_logic "${filename}/routing.txt"

    #I don't think that we need the contraints file for RS2...we have all of this information in the placement.txt file
    #write_xdc -force "${filename}/constraints.xdc"

    puts "Successfully Created RapidSmith2 Checkpoint!"
}

proc ::tincr::read_tcp {args} {
    ::tincr::parse_args {} {} {} {filename} $args
    
    set filename [::tincr::add_extension ".tcp" $filename]
    
    puts "Parsing device information file..."
    set part [get_design_info "$filename" part]
    puts "Device information obtained."
    
    puts "Reading netlist..."
    read_edif -quiet "${filename}/netlist.edf"
    puts "Netlist added successfully."
    
    puts "Reading design constraints..."
    read_xdc -quiet "${filename}/constraints.xdc"
    puts "Design constraints added successfully."
    
    puts "Reading placement and routing constraints..."
    read_xdc -quiet "${filename}/placement.xdc"
    read_xdc -quiet "${filename}/routing.xdc"
    puts "Placement and routing constraints added successfully."
    
    puts "Linking the design..."
    link_design -quiet -part $part
    puts "Design linked successfully."
    
    # Need to call place_design to flip the implemented switch
    puts "Calling place_design to flip implemented flag..."
    place_design -quiet -directive Quick
    puts "Placement complete."
    
    # Route GLOBAL LOGIC nets
    puts "Routing GLOBAL LOGIC nets..."
    route_design -quiet -physical_nets
    
    # Fix route-throughs
    set partial_nets [get_nets -hierarchical -filter {ROUTE_STATUS==ANTENNAS}]
    if {[llength $partial_nets] != 0} {
        puts "WARNING: [llength $partial_nets] nets are only partially routed. This is likely because they are route-throughs, which these tools are currently unable to handle."
        puts "Fixing route-throughs..."
        set_property IS_ROUTE_FIXED 0 $partial_nets
        route_design -quiet -nets $partial_nets
    }
    
    # Check to see if there are any unrouted nets, if so throw an error
    set unrouted_nets [get_nets -quiet -hierarchical -filter {ROUTE_STATUS==UNROUTED}]
    if {[llength $unrouted_nets] != 0} {
        puts "ERROR: The following [llength $unrouted_nets] nets are unrouted. There was a problem importing them.\n$unrouted_nets"
    }

    puts "Placement and routing imported successfully."
    
    # Unlock the design
    puts "Unlocking the design..."
    lock_design -quiet -level placement -unlock
    puts "Design unlocked."
    
    puts "Design importation complete."
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
    ::tincr::parse_args {} {} {} {filename} $args
    
    set filename [::tincr::add_extension ".xdc" $filename]
    
    set xdc [open $filename w]
    
    foreach port [get_ports] {
        if {[get_property PACKAGE_PIN $port] != ""} {
            puts $xdc "set_property PACKAGE_PIN [get_property PACKAGE_PIN $port] \[get_ports \{[get_name $port]\}\]"
        }
    }
    
    foreach cell [cells get_primitives] {
        if {[cells is_placed $cell]} {
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
    ::tincr::parse_args {} {global_logic} {} {filename} $args
    
    set filename [::tincr::add_extension ".xdc" $filename]
    
    set xdc [open $filename w]
        
    foreach site [get_sites -quiet -filter IS_USED] {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]
        
        if {$site_pips != ""} {
            puts $xdc "set_property MANUAL_ROUTE [get_property SITE_TYPE $site] \[get_sites \{[get_property NAME $site]\}\]"
            puts $xdc "set_property SITE_PIPS \{$site_pips\} \[get_sites \{[get_property NAME $site]\}\]"
        }
    }
    
    if {$global_logic} {
        set nets [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == ROUTED}]
    } else {
        set nets [get_nets -quiet -hierarchical -filter {TYPE != POWER && TYPE != GROUND && ROUTE_STATUS == ROUTED}]
    }
    foreach net $nets {
        puts $xdc "set_property ROUTE \{[get_property ROUTE $net]\} \[get_nets \{[get_property NAME $net]\}\]"
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
    
    set filename [::tincr::add_extension ".txt" $filename]
    set txt [open $filename w]
    
    #right now RS2 doesn't support top-level ports, but we may need this in the future
    foreach port [get_ports] {
        if {[get_property PACKAGE_PIN $port] != ""} {
            puts $txt "PACKAGE_PIN [get_property PACKAGE_PIN $port] [get_ports [get_name $port]]"
        }
    }
    
    #previously used the "[cells get_primitives]" function call, but we don't want the internal cells...we want the macros
    #because the EDIF netlist only spits out the MACRO cell, and our cellLibrary.xml will have all the placement information
    foreach cell [get_cells] {
        if {[tincr::cells is_placed $cell]} {
            set sitename [get_property LOC $cell]

            #For Bonded PAD sites, the XDLRC uses the package pin name rather than the actual sitename 
            if {[get_property IS_PAD [get_sites -of_object $cell]] == 1} {
                set site [get_sites $sitename]
                if {[get_property IS_BONDED $site]} {
                    set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
                }
            }
            puts $txt "LOC [get_name $cell] $sitename [get_property BEL $cell] [get_tile -of [get_sites -of $cell]]"

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
proc ::tincr::write_routing_rs2 {args} {
    set global_logic 0
    ::tincr::parse_args {} {global_logic} {} {filename} $args
    
    #create the routing file
    set filename [::tincr::add_extension ".txt" $filename]
    set txt [open $filename w]
    
    foreach site [get_sites -quiet -filter IS_USED] {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]

        if {$site_pips != ""} {
            puts $txt "MANUAL_ROUTING [get_property SITE_TYPE $site] [get_property NAME $site]"
            puts $txt "SITE_PIPS [get_property NAME $site] $site_pips"
        }
    }
    
    if {$global_logic} {
        set nets [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == ROUTED}]
    } else {
        set nets [get_nets -quiet -hierarchical -filter {TYPE != POWER && TYPE != GROUND && ROUTE_STATUS == ROUTED}]
    }
   
    foreach net $nets {
        puts $txt "ROUTE [get_property NAME $net] [get_property ROUTE $net]"
    }

    close $txt
}
