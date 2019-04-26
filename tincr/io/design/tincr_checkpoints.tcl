package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        write_tcp \
        read_rm_tcp \
        read_tcp \
        write_design_info \
        write_placement_xdc \
        write_routing_xdc \
        get_design_info \
        get_pins_to_lock\
        write_placement_rs2\
        write_routing_rs2 \
        write_rscp \
        write_rm_rscp \
        write_tcp_for_pblock \
        implement_rm \
        write_tcp_ooc_test \
        write_part_pins
}

# TODO Create bulleted list of the files in a TCP
## Writes a Tincr checkpoint to file. A Tincr checkpoint is able to store a basic design, its placement, 
#   and routing in a human-readable format. consists of five files: an EDIF netlist representation and XDC files 
#   that constrain the placement and routing of the design. Currently, designs with route-throughs are not supported, 
#   though this functionality is planned for a future release of Tincr. 
#   
#   \deprecated This function is no longer used to represent external Vivado designs. See tincr::write_rscp instead.
#
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

## Generates a RSCP. RSCPs are an external representation of a Xilinx design
#   which can be used to reconstruct Vivado designs in external CAD tools. The format
#   of RSCPs are extensively documented in the RapidSmith2 tech report found at
#   <a href="https://github.com/byuccl/RapidSmith2/tree/master/doc">https://github.com/byuccl/RapidSmith2/tree/master/doc</a>
#   and Thomas Townsend's Masters Thesis.
#
#   USAGE: tincr::write_rscp [-quiet] [-ooc] filename.rscp
#
# @params args Argument list as defined above. The flag "-quiet" 
#   can be used to suppress console output. The flag "-ooc" needs to be 
#   set for designs implemented "out-of-context". The filename parameter is the name
#   for the generated RSCP.
proc ::tincr::write_rscp {args} {
    set quiet 0
    set ooc 0
    set mode ""
    ::tincr::parse_args {} {quiet ooc} {} {filename} $args
    set filename [::tincr::add_extension ".rscp" $filename]
    file mkdir $filename   

    set old_verbose $::tincr::verbose 
    if {$quiet} {
        set ::tincr::verbose 0
    } else {
        set ::tincr::verbose 1
    }
    
    if {$ooc} {
        set mode "ooc"
    }    
       
    ::tincr::print_verbose "Writing RapidSmith2 checkpoint to $filename..."

    # generate the design info file
    write_design_info -mode $mode -part "" "${filename}/design.info"
    
    # generate the EDIF
    set start_time [clock clicks -microseconds]
    write_edif -force "${filename}/netlist.edf"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "EDIF Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # generate the macros.xml
    set start_time [clock clicks -microseconds]
    set internal_net_map [write_macros "${filename}/macros.xml"]
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Macros Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write design constraints
    set start_time [clock clicks -microseconds]
    write_xdc -force "${filename}/constraints.xdc"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "XDC Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write placement information
    set start_time [clock clicks -microseconds]
    write_placement_rs2 "${filename}/placement.rsc"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Placement Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write routing information
    set start_time [clock clicks -microseconds]
    write_routing_rs2 -global_logic "${filename}/routing.rsc" $internal_net_map
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Routing Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
     
    ::tincr::print_verbose "Successfully Created RapidSmith2 Checkpoint!"
    set ::tincr::verbose $old_verbose
}

# Note: I needed a sepeperate read_rm_tcp, so a seperate write_rm_rscp makes sense.
# TODO: Replace runtime measurements with tincr::report_runtime.
## Generates an RM RSCP. May be called either on an OOC checkpoint only containing the RM (TODO: or the full design)
#
#   USAGE: tincr::write_rm_rscp [-quiet] partialDeviceName staticDCP pblock filename
#
# @params args Argument list as defined above. 
#         The flag "-quiet"  can be used to suppress console output. 
#         The required partialDeviceName parameter is used as the part identifier in the design.info.
#         The required staticDCP parameter specifies the path to the static DCP used to identify static resources.
#         The required pBlock parameter specifies the name of the pblock that should be searched for used resources.
#         The required filename parameter is the name for the generated RSCP.
proc ::tincr::write_rm_rscp {args} {
    set quiet 0
    set partialDeviceName ""
    set staticDCP ""
    set pblock ""
    set rm_mode 1
    
    ::tincr::parse_args {} {quiet} {} {partialDeviceName staticDCP pblock filename} $args
    set filename [::tincr::add_extension ".rscp" $filename]
    file mkdir $filename

    set old_verbose $::tincr::verbose 
    if {$quiet} {
        set ::tincr::verbose 0
    } else {
        set ::tincr::verbose 1
    }
       
    ::tincr::print_verbose "Writing RapidSmith2 checkpoint to $filename..."

    # generate the design info file
    write_design_info -mode "rm" -part $partialDeviceName "${filename}/design.info"
    
    # generate the EDIF
    set start_time [clock clicks -microseconds]
    write_edif -force "${filename}/netlist.edf"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "EDIF Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # generate the macros.xml
    set start_time [clock clicks -microseconds]
    set internal_net_map [write_macros "${filename}/macros.xml"]
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Macros Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write design constraints
    set start_time [clock clicks -microseconds]
    write_xdc -force "${filename}/constraints.xdc"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "XDC Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write placement information
    set start_time [clock clicks -microseconds]
    write_placement_rs2 "${filename}/placement.rsc" $rm_mode
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Placement Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # write routing information
    set start_time [clock clicks -microseconds]
    write_routing_rs2 -global_logic "${filename}/routing.rsc" $internal_net_map
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Routing Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    # Write static used resources information   
    set start_time [clock clicks -microseconds]
    ::tincr::write_static_resources $staticDCP $pblock "${filename}/placement.rsc" "${filename}/static_resources.rsc"
    set end_time [clock clicks -microseconds]
    ::tincr::print_verbose "Static Used Resources Done...([::tincr::format_time [expr $end_time -$start_time] s]s)"
    
    ::tincr::print_verbose "Successfully Created RapidSmith2 Checkpoint!"
    set ::tincr::verbose $old_verbose
}


## Reads a RM (reconfigurable module) TCP design into a corresponding static DCP design in Vivado.
#
# USAGE: tincr::read_rm_tcp [-quiet] [-verbose] staticDCP rp_name filename
#   
#   @param args Argument list shown in the usage statement above. The "-quiet " flag
#       can be used to suppress console output. The "-verbose" flag can be used to print
#       all messages to the console. This is useful for printing error messages.
#
proc ::tincr::read_rm_tcp {args} {
    set quiet 0
    set verbose 0
    set static_dcp ""
    set rp_name ""

    ::tincr::parse_args {} {quiet verbose} {} {static_dcp rp_name filename} $args
    
    set q "-quiet"
    set ::tincr::verbose 1

    # quiet has priority over verbose if both are specified
    if {$quiet} {
        set ::tincr::verbose 0     
    } elseif {$verbose} {
        set q "-verbose"
    }
    
    # TODO: Ensure that staticDCP and rp_name are specified.
    # TODO: Throw errors if all necessary files are not found.
      
    # Open static design
    open_checkpoint $static_dcp

    lock_design -level routing
    # Update the RP blackbox with the RM netlist
    set edif_runtime [report_runtime "update_design -verbose -cells $rp_name -from_file ${filename}/netlist.edf" s]
    
    # Place and route the RM
    set place_runtime [report_runtime "read_xdc -cells $rp_name ${filename}/placement.xdc" s]
    set route_runtime [report_runtime "read_xdc -cells $rp_name ${filename}/routing.xdc" s]
    
    # Route the partition pin nets
    set partpin_runtime [report_runtime "read_xdc ${filename}/partpin_routing.xdc" s]
       
    ::tincr::print_verbose "Unlocking the design..."
    lock_design $q -level placement -unlock
    
    # Apply the (I/O) constraints again. For some reason, Vivado needs the port constraints set again, even though they are already set.
    # Otherwise, it will throw "ERROR: [DRC 23-20] Rule violation (UCIO-1) Unconstrained Logical Port", at bitgen.
    #TODO: Measure this time. Also, note that reading in the constraints.xdc at this point doesn't work for some reason.
    foreach port [get_ports] {
        set package_pin [get_property PACKAGE_PIN $port]
        set io_standard [get_property IOSTANDARD $port]
        set_property -dict "PACKAGE_PIN $package_pin IOSTANDARD $io_standard" $port
    }    
    
    set total_runtime [expr { $edif_runtime + $place_runtime + $route_runtime + $partpin_runtime} ]
    ::tincr::print_verbose "RM design importation complete. ($total_runtime seconds)"    
}

proc synth_rm {device filename} {     
	if {[glob -nocomplain ${filename}/*.sv] != ""} {
	    puts "Reading SV files..."
		set rm_list [glob ${filename}/*.sv]
        link_design -part $device
		foreach rm $rm_list {
		    read_verilog -sv $rm
		}
    }
	
    if {[glob -nocomplain ${filename}/*.v] != ""} {
	    puts "Reading Verilog files..."
		set rm_list [glob ${filename}/*.v]
        link_design -part $device
		foreach rm $rm_list {
		    read_verilog $rm
		}
    }
	
    if {[glob -nocomplain ${filename}/*.vhd] != ""} {
	    puts "Reading VHDL files..."
	    set rm_list [glob ${filename}/*.vhd]
        link_design -part $device
		foreach rm $rm_list {
			read_vhdl $rm
		}		
    }    
	synth_design -mode out_of_context -flatten_hierarchy full -top rp_top -part $device
	write_checkpoint -force reconfig_module.dcp
	close_project    
}

proc ::tincr::implement_rm {args} {
    set quiet 0
    set verbose 0
    set static_dcp ""
    set rp_name ""

    ::tincr::parse_args {static_dcp rp_name} {quiet verbose} {} {filename} $args
    
    set q "-quiet"
    set ::tincr::verbose 1

    # quiet has priority over verbose if both are specified
    if {$quiet} {
        set ::tincr::verbose 0     
    } elseif {$verbose} {
        set q "-verbose"
    }
    
    # Synth rm and save dcp
    set synth_time [report_runtime "synth_rm xc7z020clg400-1 $filename" s]

    # Open static design
    set static_time [report_runtime "open_checkpoint $static_dcp" s]

    # Set I/O constraints
    foreach port [get_ports] {
    set package_pin [get_property PACKAGE_PIN $port]
    set io_standard [get_property IOSTANDARD $port]
    set_property -dict "PACKAGE_PIN $package_pin IOSTANDARD $io_standard" $port
    } 
    
    # Lock placement and routing before reading the RM DCP into the RP
    set lock_time [report_runtime "lock_design -level routing" s]
    
    # Update the RP blackbox
    set read_dcp_runtime [report_runtime "read_checkpoint -cell $rp_name reconfig_module.dcp" s]
        
    # Place and route the RM
    set place_runtime [report_runtime "place_design" s]
    
    set route_runtime [report_runtime "route_design" s]
    
       
    set bitgen_runtime [report_runtime "write_bitstream -cell $rp_name -file ${rp_name}.bit -force" s]
       
      
    set total_runtime [expr { $synth_time + $static_time + $lock_time + $read_dcp_runtime + $place_runtime + $route_runtime + $bitgen_runtime} ]
    ::tincr::print_verbose "Synthesis complete. ($synth_time seconds)"
    ::tincr::print_verbose "Read static DCP. ($static_time seconds)"
    ::tincr::print_verbose "Locked placement, routing. ($lock_time seconds)"
    ::tincr::print_verbose "Read synthesized RM. ($read_dcp_runtime seconds)"
    ::tincr::print_verbose "Placement complete. ($place_runtime seconds)"
    ::tincr::print_verbose "Routing complete. ($route_runtime seconds)"
    ::tincr::print_verbose "Bitgen complete. ($bitgen_runtime seconds)"    
    ::tincr::print_verbose "RM design importation complete. ($total_runtime seconds)"  
}


## Parses a TCP design representation and creates an equivalent design in Vivado. 
#   The TCP format is extensively documented in the RapidSmith2 tech report at
#   <a href="https://github.com/byuccl/RapidSmith2/tree/master/doc">https://github.com/byuccl/RapidSmith2/tree/master/doc</a>
#   and Thomas Townsend's Masters thesis. The required rules to follow when formatting TCP is also
#   found in TT's Masters thesis published at BYU.
#
#   USAGE: tincr::read_tcp [-quiet] [-verbose] [-ooc] filename
#   
#   @param args Argument list shown in the usage statement above. The "-quiet " flag
#       can be used to suppress console output. The "-verbose" flag can be used to print
#       all messages to the console. This is useful for printing error messages. The flag
#       "-ooc" can be used to load a design "out_of_context". The required filename parameter
#       specifies the TCP to load into Vivado.
proc ::tincr::read_tcp {args} {
    set quiet 0
    set verbose 0
    set ooc 0
    ::tincr::parse_args {} {quiet verbose ooc} {} {filename} $args
    
    set q "-quiet"
    set ::tincr::verbose 1
    
    # quiet has priority over verbose if both are specified
    if {$quiet} {
        set ::tincr::verbose 0     
    } elseif {$verbose} {
        set q "-verbose"
    }
    
    # Set the link mode to "out_of_context" or "default" based on the command arguments
    # If a static_dcp is specified, ooc mode is implied.
    if {$ooc} {
        set link_mode "out_of_context"
    } else {
        set link_mode "default"
    }
    
    set filename [::tincr::add_extension ".tcp" $filename]

    ::tincr::print_verbose "Parsing device information file..." 
    set part [get_design_info "$filename" part]
    
    ::tincr::print_verbose "Reading netlist and constraint files..."
    set edif_runtime [report_runtime "read_edif $q ${filename}/netlist.edf" s]
    set import_fileset [create_fileset -constrset xdc_constraints]
  
    # Add all xdc files to the fileset (including extra ones a user may have added)
    add_files -fileset $import_fileset [glob ${filename}/*.xdc]
        
    ::tincr::print_verbose "Netlist and constraints added successfully. ($edif_runtime seconds)"
    ::tincr::print_verbose "Linking design (this may take awhile)..."
    set link_runtime [report_runtime "link_design $q -mode $link_mode -constrset $import_fileset -part $part" s]
    ::tincr::print_verbose "Design linked successfully. ($link_runtime seconds)"
        
    # complete the route for differential pair nets
    # there is a bug in Vivado where you can't specify the ROUTE string of a net
    # if the source is a port. It will give the error "ERROR: [Designutils 20-949] No driver found on net clock_N[0]"
    # work around is to have Vivado route these nets for us ...
    # TODO: add another part to the filter that says the nets are not routed
    # TODO: Don't do this if the TCP is a pre-route TCP?
    set diff_time 0
    if {$link_mode=="default"} {
        set differential_nets [get_nets -of [get_ports] -filter {ROUTE_STATUS != INTRASITE} -quiet]
        
        if {[llength $differential_nets] > 0 } {
            ::tincr::print_verbose "Routing [llength $differential_nets] differential pair nets..."
            set diff_time [tincr::report_runtime "route_design -quiet -nets [subst -novariables {$differential_nets}]" s]
            ::tincr::print_verbose "Done routing...($diff_time seconds)"
        }
    }       
  
    ::tincr::print_verbose "Unlocking the design..."
    lock_design $q -level placement -unlock

    set total_runtime [expr { $edif_runtime + $link_runtime + $diff_time} ]
    ::tincr::print_verbose "Design importation complete. ($total_runtime seconds)"
}

## Sorts the cells of SLICE sites in the the order that is required to import the design successfully. 
#
# @param cells List of cells to sort
# @return A list of sorted cells
proc ::tincr::sort_cells_for_export { cells } {

    set primitives [list]
    set luts [list]
    set carrys [list]
    set ff [list]
    set ff_5 [list]

    # TODO: Eventually, we may have to look through all of the cells
    #       (internal cells of macros) to support macros.
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

## Creates the "design.info" file of a RSCP.
#   
#   USAGE: tincr::write_design_info filename
#
# @param args Argument list shown in the usage statement above. The optional parameter
#       "ooc" is used to output the mode of the design. The "-part partName"  
#   option is used as the part identifier in the design.info if specified.
#   The filename parameter is the name for the generated design.info.
proc ::tincr::write_design_info {args} {
    set mode ""
    set partName ""
    ::tincr::parse_args {mode partName} {} {} {filename} $args

    set filename [::tincr::add_extension ".info" $filename]

    set outfile [open $filename w]
    
    # if no partName is specified, get the part from the design
    if {$partName == ""} {
        set partName "[get_property PART [current_design]]"
    }

    puts $outfile "part=$partName"
    
    if { ($mode eq "ooc") || ($mode eq "out_of_context") } {
        puts $outfile "mode=out_of_context"
    } elseif { ($mode eq "rm") || ($mode eq "reconfig_module") } {
        puts $outfile "mode=reconfig_module"
    } else {
        puts $outfile "mode=regular"
    }
    
    close $outfile
}

## Writes a "routing.xdc" file for a TCP. This contains all
#   routing information for a design.
#
# \deprecated This function is no longer used to represent routing. See tincr::write_routing_rs2 instead.
#
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

## Parses a design.info file of a TCP and returns the requested information.
#   Currently, it is used to parse the partname that a given design is
#   implemented on.
#
#   USAGE: tincr::get_design_info filename info
#
# @param Argument list shown in the usage statement above. The parameter
#       "filename" is the design.info file to parse. The parameter "info"
#       is the name of the key to parse (i.e. part).
#
# @return The value of the specified key, or "" if the key is not found
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

## Looks for macro cells in the design that aren't in the list of cells returned from
# the function call "get_lib_cells", and writes the cell library XML for these cells.
# TODO: add caching to this
# @return A dictionary that maps macro cell type, to the internal nets of the macro
#        These nets need to be included in the routing.rsc checkpoints
proc ::tincr::write_macros { {filename macros.xml } } {
    set filename [::tincr::add_extension ".xml" $filename]
    set xml [open $filename w]
    
    # create list of cells in the cell library
    # TODO: cache this...
    set lib_cell_set ""
    set macro_set ""
    foreach lib_cell [get_lib_cells] {
        ::struct::set add lib_cell_set $lib_cell
    }
        
    puts $xml {<?xml version="1.0" encoding="UTF-8"?>}
    puts $xml "<root>"
    puts $xml "  <macros>"
    
    # I'm assuming the "PRIMITIVE_COUNT > 1" part of this is here due to the assumption that a macro will have more
    # than one primitive inside of it. I think this assumption is broken when dealing with RMs...
    set macro_cells [get_cells -filter {PRIMITIVE_LEVEL==MACRO || (PRIMITIVE_COUNT > 1 && PARENT=="")} -quiet]
    
    #set macro_cells [get_cells -hierarchical -quiet]
    
    #set macro_cells [get_cells -filter {PRIMITIVE_LEVEL==MACRO || (PRIMITIVE_COUNT > 0 && PARENT=="")} -quiet]
    set macros_to_write [list]
    set macros_in_design [list]
    
    # look for macros that aren't contained in the default call to "[get_lib_cells]"
    # TODO: need to add existing macros
    foreach macro $macro_cells {
        set ref_name [get_property REF_NAME $macro]
        # find macros whose XML need to be included in the checkpoint
        if {[::struct::set contains $lib_cell_set $ref_name] == 0}  {
            ::struct::set add lib_cell_set $ref_name
            lappend macros_to_write $macro
        }
        
        # find all macros types in the current design.
        if {[::struct::set contains $macro_set $ref_name] == 0}  {
            ::struct::set add macro_set $ref_name
            lappend macros_in_design $macro
        }
    }
    
    set internal_net_map [dict create]
    # write the XML for new macros
    foreach macro $macros_to_write {
        set internal_nets [tincr::write_macro_xml $macro $xml]
        dict set internal_net_map [get_property REF_NAME $macro] $internal_nets
    }
        
    # Create the map of type -> internal netnames for all macros
    foreach macro $macros_in_design {
        if { [dict exists $internal_net_map [get_property REF_NAME $macro]] == 0 } {
            dict set internal_net_map [get_property REF_NAME $macro] [get_internal_macro_nets $macro]
        }
    }
    
    puts $xml "  </macros>"
    puts $xml "</root>"
    
    close $xml
    return $internal_net_map
}

## Creates the "placement.rsc" file within a RSCP. This contains all placement information
#   about a design including:
#       - Cell to BEL mappings
#       - Cell pin to BEL pin mappings
#       - Top-level port placement
#       - Internal cell properties
#
# @param filename The name of the placement checkpoint file, "placement.rsc" is the default.
# @param rm_mode If 1, the mode is reconfig_module.
# @param pblock If specified, only get placement info for resources within the pblock.
proc ::tincr::write_placement_rs2 { {filename placement.rsc} {rm_mode 0} }  {

    set filename [::tincr::add_extension ".rsc" $filename]
    set txt [open $filename w]
    
    # determine if the current device is a series7 or not
    set is_series7 [::tincr::parts::is_series7]
    
    # First, write all internal cell properties that were not included in the EDIF netlist    
    foreach internal_cell [get_cells -hierarchical -filter {PRIMITIVE_LEVEL==INTERNAL && PRIMITIVE_COUNT==1} -quiet] {
        
        foreach property [tincr::cells::get_configurable_properties $internal_cell] {
           
            set value [get_property $property $internal_cell]
            # only print the configurations to the file if a value exists, and its not the default value
            # this is the same behavior as EDIF
            if {$value != "" && $value != [tincr::get_default_value $internal_cell $property]} { 
                puts $txt "IPROP $internal_cell $property $value"
            }
        }
    }

    # write placement information for leaf and internal cells
    set cells [get_cells -hierarchical -filter {PRIMITIVE_LEVEL!=MACRO && BEL!="" && PRIMITIVE_COUNT==1}]

    # print the placement location and pin-mappings foreach cell in the design
    foreach cell $cells {
        
        set site [get_sites -of $cell]
        set sitename [get_property LOC $cell]
        
        #For Bonded PAD sites, the XDLRC uses the package pin name rather than the actual sitename
        if { [get_property IS_PAD $site] && $is_series7 } {
            set sitename [get_property NAME [get_package_pins -quiet -of_object $site]]
        }

        set bel_toks [split [get_property BEL $cell] "."]
        
        # NOTE: We have to do this, because the SITE_TYPE property of sites are not updated correctly
        #      when you place cells there. BUFG is an example
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
    foreach site [get_sites -of [get_ports -quiet] -quiet] {
        foreach bel [get_bels -of $site -filter TYPE=~*PAD*] {
            set net [get_nets -of $bel]
            if { [llength $net] == 1 } {
                set port [get_ports -of $net]
                set bel_name [lindex [split $bel "/"] end]
                if {$is_series7} {
                    puts $txt "PACKAGE_PIN [get_property NAME $port] [get_property PACKAGE_PIN $port] $bel_name"
                } else {
                    puts $txt "PACKAGE_PIN [get_property NAME $port] [get_property NAME $site] $bel_name"
                }
            }
        }
    }
    
    # write out-of-context hierarchical ports to the file
    if {!$rm_mode} {
        ::tincr::write_part_pins $txt
    }
    
    close $txt
}

## Finds the nets inside of macro primitives that are NOT connected to 
#   a macro pin. The routing information for these nets need to be
#   exported when creating a RSCP.
#
# @param macro Macro cell instance 
# @return A list of internal macro nets
proc ::tincr::get_internal_macro_nets {macro} {
    set boundary_nets ""
    foreach pin [get_pins -of $macro] {
        set internal_net [get_nets -boundary_type lower -of $pin]
        ::struct::set add boundary_nets $internal_net
    }   
    
    set internal_nets [list]
    foreach net [get_nets $macro/*] {
        # skip nets that connect to the macro boundary        
        if {![::struct::set contains $boundary_nets $net]} {
            set last [expr {[string last "/" $net] + 1}]
            set netname [string range $net $last end] 
            lappend internal_nets $netname
        }
    }
    
    foreach icell [get_cells $macro/* -filter {PRIMITIVE_COUNT > 1} -quiet] {
        foreach pin [get_pins -of $icell] {
            ::struct::set add boundary_nets [get_nets -boundary_type lower -of $pin]
        }
        
        set outer_cell_name [lindex [split $icell "/"] end]
        foreach net [get_nets $icell/*] {
            if {[::struct::set contains $boundary_nets $net] == 0} {
                set inner_net_name [lindex [split $net "/"] end]
                lappend internal_nets "$outer_cell_name/$inner_net_name"
            }
        }
    }
    
    return $internal_nets
}

## Creates the "routing.rsc" file within a RSCP. This file includes:
#   - Used site pips for each site
#   - Pips in each net
#   - Site pins attached to each net
#   - BEL Routethroughs
#   - Static Source BELs
#   - Merged VCC/GND net information 
#
#   USAGE: tincr::write_routing_rs2 [-global_logic] filename
# @param args Argument list shown in the usage statement above. The flag "-global_logic"
#       is used to include VCC and GND routing. The parameter "filename" is the name
#       of the file to write the routing information to. The parameter "internal_net_map"
#       is a list of internal macro nets so the routing information for these nets can be exported.
proc ::tincr::write_routing_rs2 {args} {
    set global_logic 0
    ::tincr::parse_args {} {global_logic} {} {filename internal_net_map} $args

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
    
    # select which nets to export (do not get the hierarchical nets)
    if {$global_logic} {
        set nets [get_nets -quiet]
    } else {
        set nets [get_nets -quiet -filter {TYPE != POWER && TYPE != GROUND}]
    }
    
    # Add internal hierarchical nets to the list of nets whose routing information should be printed 
    foreach macro [get_cells -filter {PRIMITIVE_LEVEL==MACRO || (PRIMITIVE_COUNT>1 && PARENT=="") } -quiet] {
        foreach netname [dict get $internal_net_map [get_property REF_NAME $macro]] {
            lappend nets [get_nets $macro/$netname]    
        }
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
    
    set is_series7 [::tincr::parts::is_series7] 
    
    foreach site $site_list {
        set site_pips [get_site_pips -quiet -of_objects $site -filter IS_USED]

        if {$site_pips != ""} {

            set sitename [get_property NAME $site]

            if { [get_property IS_PAD $site] && $is_series7 } {
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
#   these BELs to the routing export file.
#
# @param site_list List of <b>used</b> sites in the design
# @param channel Output file handle
proc write_static_and_routethrough_luts { site_list channel } {
    
    set vcc_sources [list]
    set gnd_sources [list]
    set routethrough_luts [list]
    set MAX_CONFIG_SIZE 20
    
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
    
    # print the gnd sources, vcc sources, and lut routethroughs to the routing file
    ::tincr::print_list -header "VCC_SOURCES" -channel $channel $vcc_sources
    ::tincr::print_list -header "GND_SOURCES" -channel $channel $gnd_sources
    ::tincr::print_list -header "LUT_RTS" -channel $channel $routethrough_luts
}

## Finds all out-of-context ports in a design and adds them to the routing.rsc file. 
#   This only occurs for designs implemented in out-of-context mode. Out-of-context ports
#   are those that aren't mapped to PAD BELs, but are partially routed to a specific
#   wire in the device. The device wire represents the start/end wire of nets connected
#   to the port.
#
# @param channel File handle to write the ooc ports to
#proc write_ooc_ports {channel} {
#    # for OOC checkpoints with hierarchical ports, print the starting wires for each port
#    # OOC checkpoints has the design property IS_BLOCK set to true
#    if {[get_property IS_BLOCK [current_design]]} {
#        # TODO: could change this to have a token of "OOC_PORTS" with a list of ports all on one line, but his is oke for now
#        foreach ooc_port [get_ports -filter HD.ASSIGNED_PPLOCS!="" -quiet] {
#             #TODO: Remove the hierarchical part of it? i.e. alu_reconfig/a -> a
#             puts $channel "OOC_PORT $ooc_port [string map {" " "/"} [get_property HD.ASSIGNED_PPLOCS $ooc_port]]" 
#        }
#    }
#} 

## Finds partition pins (out-of-context ports) in a design and adds them to the placement.rsc file. 
#   Out-of-context ports are those that aren't mapped to PAD BELs, but are partially routed to a specific
#   wire in the device. The device wire represents the start/end wire of nets connected
#   to the port.
#
# @param channel File handle to write the ooc ports to
proc ::tincr::write_part_pins {channel} {
    foreach part_pin [get_pins -filter HD.ASSIGNED_PPLOCS!="" -quiet] {
	     set pin_name [get_property REF_PIN_NAME [get_pins $part_pin]]
		 set direction [get_property DIRECTION [get_pins $part_pin]]
		 
		 # Change the direction to be from the correct perspective
		 set direction [expr {$direction eq "IN" ? "OUT" : "IN"}] 
		 
		 # Get the partition pin's wire
		 set wire_name [string map {" " "/"} [get_property HD.ASSIGNED_PPLOCS $part_pin]]
		 
		 # Use the wire to get the partition pin's node
		 set node [get_nodes -of_object [get_wires $wire_name]]
		 
         # Are there cases where the wire is needed instead of the node?
         puts $channel "PART_PIN $pin_name $node $direction" 
    }
} 



## Writes the physical elements used in each net of the design. This includes the
#   pips and site pins of the net. VCC and GND nets are treated specially. The physical 
#   components of these nets are collapsed into one, and all exported together. This means,
#   VCC and GND are both only represented once in the routing export file.
#
# @param net_list A list of nets in the design to export
# @param channel Output file handle
proc write_net_routing { net_list channel } {
   
    # disable the TCL display limit to fully print a list of wires
    tincr::set_tcl_display_limit 0
    set is_series7 [::tincr::parts::is_series7]
    
    set vcc_sinks [list]
    set gnd_sinks [list]
    
    set vcc_net ""
    set gnd_net ""
    
    foreach net $net_list {
    
        set status [get_property ROUTE_STATUS $net]
        set type [get_property TYPE $net]
       
        if {$is_series7} {
            set site_pins [tincr::nets::get_site_pins_of_net $net]
        } else {
            set site_pins [tincr::nets::get_site_pins_hierarchical $net]
        }
        
        if {$type == "POWER"} { ; # VCC net
                      
            if {[llength $site_pins] > 0 } {
                lappend vcc_sinks $site_pins
            }
            
            if {$vcc_net == ""} {
                set vcc_net $net
            }           
        } elseif {$type == "GROUND"} { ; # GND net
            
            if {[llength $site_pins] > 0 } {
                lappend gnd_sinks $site_pins
            }
            
            if {$gnd_net == ""} {
                set gnd_net $net
            } 
        } elseif {$status == "INTRASITE"} {
            # mark nets as intrasite in the output routing file
            puts $channel "INTRASITE [get_property NAME $net]"
        } else { ; # regular nets
                        
            set net_name [get_property NAME $net]
            
            # add the site pins the routing export file if any exist
            if {[llength $site_pins] > 0} {            
                write_intersite_pins $net_name $site_pins $channel
            }
            
            # add the wires of the net to the routing export file for routed nets
            set route_status [get_property ROUTE_STATUS $net]
            set route_string [get_property ROUTE $net]
            # only print non-empty route strings for routing nets.
            if { ( $route_status=="ROUTED" || $route_status=="HIERPORT" ) && $route_string != "{}" } {
                puts $channel "ROUTE $net_name [get_pips -of $net]"
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
    
    set vcc_pips [get_pips -of $vcc_net -quiet]
    if {[llength $vcc_pips] > 0} {
        puts $channel "VCC $vcc_pips"
        puts $channel "START_WIRES [tincr::nets::get_static_source_wires $vcc_net]"
    }
    
    set gnd_pips [get_pips -of $gnd_net -quiet]
    if {[llength $gnd_pips] > 0} {
        puts $channel "GND $gnd_pips"
        puts $channel "START_WIRES [tincr::nets::get_static_source_wires $gnd_net]"
    }
    
    # re-enable the TCL display limit
    tincr::reset_tcl_display_limit 
}

## Writes the site pins connected to the specified net, to the specified output channel in the form:
#   {@code INTERSITE netName site0/pin0 site1/pin1 ... siteN/pinN}
#
# @param net_name Name of a net in the design
# @param site_pin_list A list of site pins connected to that net
# @param channel Output file handle
proc write_intersite_pins { net_name site_pin_list channel } {
    
    set is_series7 [::tincr::parts::is_series7]
    
    puts -nonewline $channel "INTERSITE $net_name "
    
    foreach site_pin $site_pin_list {
        set toks [split $site_pin "/"]
        
        set sitename [lindex $toks 0]
        set pinname [lindex $toks 1]
        set site [get_sites $sitename]
        
        if {[get_property IS_PAD $site] && $is_series7} {
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
