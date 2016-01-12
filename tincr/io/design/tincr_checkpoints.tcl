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
        get_design_info
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
            
            set group [get_property PRIMITIVE_GROUP $cell]
            if {$group == "LUT" || $group == "INV" || $group == "BUF"} {
                set pins_to_lock [list]
                foreach pin [get_pins -of_object $cell -filter {DIRECTION == IN}] {
                    set bel_pin [get_bel_pins -quiet -of_object $pin]
                    
                    if {$bel_pin != ""} {
                        #TODO These get_*_info commands should be deprecated
                        lappend pins_to_lock "[::tincr::pins info $pin name]:[::tincr::bel_pins get_info $bel_pin name]"
                    }
                }
                            
                if {[llength $pins_to_lock] != 0} {
                    puts $xdc "set_property LOCK_PINS \{$pins_to_lock\} \[get_cells \{[get_name $cell]\}\]"
                }
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