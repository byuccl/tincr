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
    puts "EDIF Done..."
    write_xdc -force "${filename}/constraints.rsc"
    puts "XDC Done..."
    write_placement_rs2 "${filename}/placement.rsc"
    puts "Placement Done..."
    write_routing_rs2 -global_logic "${filename}/routing.rsc"
    puts "Routing Done..."
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
    
    ::tincr::print_verbose "Reading netlist and constraint files..."
    set edif_runtime [report_runtime "read_edif $q ${filename}/netlist.edf" s]
    set import_fileset [create_fileset -constrset xdc_constraints]
    add_files -fileset $import_fileset [glob ${filename}/*.xdc] 
    ::tincr::print_verbose "Netlist and constraints added successfully. ($edif_runtime seconds)"

    ::tincr::print_verbose "Linking design (this may take awhile)..."
    set link_runtime [report_runtime "link_design $q -constrset $import_fileset -part $part" s]
    ::tincr::print_verbose "Design linked successfully. ($link_runtime seconds)"
    
    # complete the route for differential pair nets
    # there is a bug in Vivado where you can't specify the ROUTE string of a net
    # if the source is a port. It will give the error "ERROR: [Designutils 20-949] No driver found on net clock_N[0]"
    # work around is to have Vivado route these nets for us ...
    set differential_nets [get_nets -of [get_ports] -filter {ROUTE_STATUS != INTRASITE}]
    
    if {[llength $differential_nets] > 0 } {
        ::tincr::print_verbose "Routing [llength $differential_nets] differential pair nets..."
        # format_time does not work for this route design command, so I have to do it manually here
        set start_time [clock microseconds]
        route_design -quiet -nets $differential_nets
        set end_time [clock microseconds]
        set diff_time [::tincr::format_time [expr $end_time - $start_time] s]
        ::tincr::print_verbose "Done routing...($diff_time seconds)"
    }
    
    ::tincr::print_verbose "Unlocking the design..."
    lock_design $q -level placement -unlock

    set total_runtime [expr { $edif_runtime + $link_runtime + $diff_time} ]
    # unlock the design at the end of the import process...do we need to do this?
    ::tincr::print_verbose "Design importation complete. ($total_runtime seconds)"
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

## For a LUT cell, this function returns the pin mappings of the LUTs input pins
#
# @param cell Cell in the currently opened design
# @return A list of pin mappings in the form "cellPin:belPin"
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

## Creates the "placement.rsc" file within a TINCR checkpoint targeting RapidSmith
#
# @param filename The name of the placement checkpoint file, "placement.rsc" is the default.
proc ::tincr::write_placement_rs2 { {filename placement.rsc} }  {

    set filename [::tincr::add_extension ".rsc" $filename]
    set txt [open $filename w]

    # TODO: if/when macros are supported, update this function
    set cells [get_cells -hierarchical -filter {PRIMITIVE_LEVEL==LEAF && STATUS!=UNPLACED}]

    # print the placement location and pin-mappings foreach cell in the design 
    foreach cell $cells {
        
        set site [get_sites -of $cell]
        set sitename [get_property LOC $cell]
        
        #For Bonded PAD sites, the XDLRC uses the package pin name rather than the actual sitename
        if { [get_property IS_PAD $site] } {
            set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
        }

        set bel_toks [split [get_property BEL $cell] "."]
        
        # NOTE: We have to do this, because the SITE_TYPE property of sites are not updated correctly
        #	   when you place cells there. BUFG is an example
        set sitetype [lindex $bel_toks 0]
        set bel [lindex $bel_toks end]
        set tile [get_tile -of $site]

        puts $txt "LOC [get_name $cell] $sitename $sitetype $bel $tile"

        set pin_map ""
        # print the pin mappings to the TINCR checkpoint file
        foreach pin [get_pins -of $cell] {
            append pin_map [get_property REF_PIN_NAME $pin]
            
            foreach bel_pin [get_bel_pins -of $pin -quiet] {
                
                # bel_pins follow the naming format: site/bel/pin_name
                set bel_name_toks [split $bel_pin "/"]
                
                set bel_name [lindex $bel_name_toks 1]
                set bel_pin_name [lindex $bel_name_toks end]
                
                # only add a pin mapping if its to the same bel
                if {$bel_name == $bel} {
                    append pin_map ":$bel_pin_name"
                }
            }
            append pin_map " "
        }
        
        puts $txt "PINMAP [get_name $cell] $pin_map"
    }
    
    # write the port information to the checkpoint file AFTER the cell information
    foreach port [get_ports] {
        if {[get_property PACKAGE_PIN $port] != ""} {
            puts $txt "PACKAGE_PIN [get_property PACKAGE_PIN $port] [get_ports [get_name $port]]"
        }
    }

    close $txt
}

## Gets the name of a site that RapidSmith expects. The only time this is different than the
#   name from {@code [get_property NAME $site] is if the site is an input or output PAD. In this
#   case, the RapidSmith site name is the package pin name .
#
# @param site Site object
proc get_rapidSmith_sitename { site } {
    set sitename [get_property SITENAME $site]
    
    if {[get_property IS_PAD $site] == 1} {
        set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
    }

    return $sitename
} 

## Creates the RapidSmith routing checkpoint file. This file includes the site pips for each site,
#   the wires in each net, the site pins attached to each net, the BELs that are being used
#   as a static source, and the BELs that are being used as routethroughs 
#
# @param args A string of arguments into the function. Usage is as follows: <br>
#           "tincr::write_routing_rs2 [-global_logic] filename"
proc ::tincr::write_routing_rs2 {args} {
    set global_logic 0
    ::tincr::parse_args {} {global_logic} {} {filename} $args

    # create the routing file
    set filename [::tincr::add_extension ".rsc" $filename]
    set channel_out [open $filename w]

    # write the used sites pips to the file
    set used_sites [get_sites -quiet -filter IS_USED] 
    write_site_pips $used_sites $channel_out
    
    set single_port_sites [get_sites -quiet -of [get_ports] -filter {!IS_USED}]
    write_site_pips $single_port_sites $channel_out
    
    # write the static and routethrough lut information to the file
    write_static_and_routethrough_luts $used_sites $channel_out
    
    # select which nets to export
    if {$global_logic} {
    	set nets [get_nets -quiet -hierarchical]
    } else {
    	set nets [get_nets -quiet -hierarchical -filter {TYPE != POWER && TYPE != GROUND}]
    }

    # write the physical routing information of each net
    write_net_routing $nets $channel_out
   
    close $channel_out
}

## Writes the Site PIP information for each of the sites in site_list to the
#   specified output channel/file. For each site, the site pips are written in the
#   following format: <br>
#   {@code "SITE_PIPS siteName pip0:pin0 pip1:pin1 ... pipN:"}
#
# @param site_list List of <b>used</b> sites in the design
# @param channel Output file handle 
proc write_site_pips { site_list channel } {
    
    foreach site $site_list {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]

        if {$site_pips != ""} {

            set sitename [get_property NAME $site]

            if { [get_property IS_PAD $site] && [get_property IS_BONDED $site] } {
                set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
            }

            puts -nonewline $channel "SITE_PIPS $sitename "

            foreach sp $site_pips {
                puts -nonewline $channel "[lindex [split $sp "/"] end] "
            }
            puts $channel {}
        }
    }
}

## Searches through the used sites of the design, identifies LUT BELs that are being
#   used as either a routethrough or static source (always outputs 1 or 0), and writes
#   identifies these BELs in the routing export file.
#
# @param site_list List of <b>used</b> sites in the design
# @param channel Output file handle
proc write_static_and_routethrough_luts { site_list channel } {
    
    set static_sources [list]
    set routethrough_luts [list]
    set MAX_CONFIG_SIZE 20
    foreach bel [get_bels -quiet -of $site_list -filter {TYPE =~ LUT* && !IS_USED}] {
        
        set config [get_property CONFIG.EQN $bel]
        
        # skip long config strings...they cannot be static sources or routethroughs
        if { [string length $config] > $MAX_CONFIG_SIZE } {
            continue
        }
        
        if { [regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(?[0,1]\)? ?} $config -> pin] } { ; # GND/VCC source
            lappend static_sources "[get_property NAME $bel]/$pin"
        } elseif { [regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(+(A[1-6])\)+ ?} $config -> outpin inpin] } { ; # LUT routethrough
            lappend routethrough_luts "$bel/$inpin/$outpin"
        }
    }
    
    # print the gnd sources, vcc sources, and lut routethroughs to the routing file
    ::tincr::print_list -header "STATIC_SOURCES" -channel $channel $static_sources
    ::tincr::print_list -header "LUT_RTS" -channel $channel $routethrough_luts
}

## Writes the physical elements used in each net of the design. This includes the
#   wires and site pins of the net. VCC and GND nets are treated specially. The physical 
#   components of these nets are collapsed into one, and all exported together. This means,
#   VCC and GND are both only represented once in the routing export file.
#
# @param net_list A list of nets in the design to export
# @param channel Output file handle
proc write_net_routing { net_list channel } {

    # disable the TCL display limit to fully print a list of wires
    tincr::set_tcl_display_limit 0
    
    set vcc_sinks [list]
    set gnd_sinks [list]
    set vcc_wires [list]
    set gnd_wires [list]
    set vcc_route_string ""
    set gnd_route_string ""
    
    foreach net $net_list {
    
        set status [get_property ROUTE_STATUS $net]
        set type [get_property TYPE $net]
       
        if {$type == "POWER"} { ; # VCC net
            
            set site_sinks [get_site_pins_of_net $net]
            if {[llength $site_sinks] > 0 } {
                lappend vcc_sinks $site_sinks
            }
            
            if {[llength $vcc_wires] == 0} {
                set vcc_wires [get_wires -of $net -quiet]
                set vcc_route_string [get_property ROUTE $net]
            }
                       
        } elseif {$type == "GROUND"} { ; # GND net
            
            set site_sinks [get_site_pins_of_net $net]
            if {[llength $site_sinks] > 0 } {
                lappend gnd_sinks $site_sinks
            }
            
            if {[llength $gnd_wires] == 0} {
                set gnd_wires [get_wires -of $net -quiet]
                set gnd_route_string [get_property ROUTE $net]
            }
               
        } elseif {$status == "INTRASITE"} {
            # mark nets as intrasite in the output routing file
            puts $channel "INTRASITE [get_property NAME $net]"
        } else { ; # regular nets
            
            set site_pins [get_site_pins_of_net $net]
            set net_name [get_property NAME $net]
            
            # add the site pins the routing export file if any exist
            if {[llength $site_pins] > 0} {            
                write_intersite_pins $net_name $site_pins $channel
            }
            
            # add the wires of the net to the routing export file if any exist
            set route_string [get_property ROUTE $net]
            
            # only print non-empty route strings.
            if {$route_string != "{}"} {
                puts $channel "ROUTE $net_name [get_wires -of $net]"
            }
        }
    }
    
    # add VCC and GND information to the file last (only print if there is a route string)
    if {[llength $vcc_sinks] > 0} {
        puts $channel "INTERSITE VCC [join $vcc_sinks]"
    }
    
    if {[llength $gnd_sinks] > 0} {
        puts $channel "INTERSITE GND [join $gnd_sinks]"
    }
    
    if {[llength $vcc_wires] > 0} {
        puts "Printing VCC"
        puts $channel "VCC $vcc_wires"
        puts $channel "START_WIRES [get_static_source_wires $vcc_route_string $vcc_wires]"
    }
    
    if {[llength $gnd_wires] > 0} {
        puts "Printing GND"
        puts $channel "GND $gnd_wires"
        puts $channel "START_WIRES [get_static_source_wires $gnd_route_string $gnd_wires]"
    }
    
    # re-enable the TCL display limit
    tincr::reset_tcl_display_limit 
}

## Returns the source wires of VCC and GND nets (i.e. the wires that are connected to tieoff bels).
#   This is done by parsing the ROUTE string of these nets, and grabbing the first wire within each
#   independent section (which are separated by parenthesis "()")
#
# @param route_string The ROUTE string of the static net
# @param net_wires The wires within the static net
# @return A list of all source wires in the net
proc get_static_source_wires {route_string net_wires} {
    
    set toks [regexp -all -inline {\S+} $route_string] 
    set start_list [list]
 

    if { [lindex $toks 0] == "\{" } { ; 
        # special case for a single tieoff...use the net wires here
        lappend start_list [lindex $net_wires 0]
    } else { ; 
        # multiple tieoffs, the ROUTE strings look like ({wireA0 wireA1... } ) ( {wireB0 wireB1 ...} ) ... 
        for {set i 0} {$i < [llength $toks]} { incr i } {
            set tok [lindex $toks $i]
            
            if {$tok=="("} {
                incr i 2
                lappend start_list [lindex $toks $i]
            }
        }
    }
    
    return $start_list
}

## Gets the site pins connected to the specified net. The TCL call {@code get_site_pins -of $net}
#   cannot be used because there is a bug in Vivado with alternate site type site pins. When a site is switched
#   to an alternate type, the site pins are not updated in the TCL interface, but they may have changed.
#   This function identifies these pins, and returns the correct site pins in this scenario.
#
# @param net TCL net object
# @return a list of corrected site pins connected to the net
proc get_site_pins_of_net {net} {
    
    set pin_set [list]
    
    foreach bel_pin [get_bel_pins -of $net] {
        if {[llength [get_bels -of [get_sites -of $bel_pin]]] == 1} {
            # if there is only one bel in the site, the bel pin name will match its corresponding site pin.
            set belPinToks [split $bel_pin "/"]
            ::struct::set add pin_set "[lindex $belPinToks 0]/[lindex $belPinToks 2]"
        } else {
            
            foreach site_pin [get_site_pins -of [get_pins -of $bel_pin -quiet] -quiet] {
                ::struct::set add pin_set $site_pin
            }
        }
    }
    
    return $pin_set
}

## Writes the site pins connected to the specified net, to the specified output channel in the form:
#   {@code INTERSITE netName site0/pin0 site1/pin1 ... siteN/pinN}
#
# @param net_name Name of a net in the design
# @param site_pin_list A list of site pins connected to that net
# @param channel Output file handle
proc write_intersite_pins { net_name site_pin_list channel } {
    
    puts -nonewline $channel "INTERSITE $net_name "
    
    foreach site_pin $site_pin_list {
        set toks [split $site_pin "/"]
        
        set sitename [lindex $toks 0]
        set pinname [lindex $toks 1]
        set site [get_sites $sitename]
        
        if {[get_property IS_PAD $site]} {
            set sitename [get_property NAME [get_package_pins -quiet -of $site]]
        }
        puts -nonewline $channel "$sitename/$pinname "                
    }
    puts $channel {}
}

# --------------------------------------
# Code for pblocks and parallel import
# Still in the stages of testing
# --------------------------------------

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
