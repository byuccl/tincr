package provide tincr.io.library 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        createCellLibrary
}

# This script creates the cellLibrary.xml file needed for RapidSmith2.
# All function used are encapsulated into this file
# TODO: Incorporate this into the TINCR distribution

#open a new design in Vivado with the specified part
proc createBlankDesignByPart { part } {
    return [tincr::designs new mydes $part]
}

# helper function used to get the relative name of Vivado elements
# TODO: add to tincr.util
proc suffix { s p } {
    return [lindex [split $s $p] end]
}

# test if a cell can be placed on a particular BEL
# TODO: Add to tincr::cell
proc is_my_placement_legal { c b } {
    unplace_cell $c

    if {[catch {place_cell $c $b} fid] == 0} {
        if { [suffix $b "/"] == [suffix [get_property BEL $c] "."] } then {
            unplace_cell $c
            return 1
        } else {
            unplace_cell $c
            return 0
        }
    }
    return 0
}

# create a list of all supported cells in the current design
# TODO: find a way to merge the top and bottom funtion
proc getSupportedLeafLibCells { } {
    set lib_cells [get_lib_cells]
    set supported_cells [list]
    set i 0

    foreach lbc $lib_cells {
        set c [create_cell -reference $lbc "cell_$i" -quiet]

        if {[get_property REF_NAME $c] == $lbc && [get_property PRIMITIVE_LEVEL $c] == "LEAF"} {
            lappend supported_cells $lbc
        } else {
            remove_cell [get_cells cell_$i]
        }
        incr i
    }

    return $supported_cells
}

#create a list of all supported cells in the current design
# TODO: update this
proc getSupportedLibCells { } {
    set lib_cells [get_lib_cells]
    set supported_cells [list]

    foreach lbc $lib_cells {
        set c [create_cell -reference $lbc tmp -quiet]

        if {[get_property REF_NAME $c] == $lbc} {
            lappend supported_cells $lbc
        }
        remove_cell [get_cells tmp]
    }

    return $supported_cells
}

# modified version of the tincr::sites::unique function to get a handle to each primitive site type
# it chooses default site locations over alternate site locations
proc uniqueSites {} {
    set sites [dict create]
    set alternates [dict create]

    foreach site [get_sites] {
        #create a dictionary of default site types
        if {![dict exists $sites [get_property SITE_TYPE $site]]} {
            dict set sites [get_property SITE_TYPE $site] $site
        }

        #create a dictionary of alternate site types
        foreach type [get_property ALTERNATE_SITE_TYPES $site] {
            if {![dict exists $alternates $type]} {
                dict set alternates $type $site
            }
        }
    }

    # If a site in the alternate dictionary is not already in the default dictionary, add it
    # NOTE: IOB sites cause Vivado to crash when you set alternate site types that are IOBs
    #   so, unfortunately, we have to ignore these until the bug is fixed.
    dict for {type site} $alternates {
        if {![dict exists $sites $type] &&  ![regexp {.*IOB*} $type]} {
            dict set sites $type $site
        }
    }

    return $sites
}

#
#Input parameters: list of library cells and a dictionary of sites
proc createCellToSiteMap {lib_cells site_map} {
    set should_reset 0
    set cell_site_map [dict create]

    foreach lbc $lib_cells {
        set c [create_cell -reference $lbc tmp -quiet]

        # try to place each lib_cell on each site
        dict for {sitename site} $site_map {

            if { [regexp {.*IOB*} $sitename] == 0 } {
                set_property MANUAL_ROUTING $sitename $site
                set should_reset 1
            }

            if {[catch {[place_cell $c $site]} err] == 0} {
                dict lappend cell_site_map $lbc $sitename
                unplace_cell $c
            }

            if { $should_reset } {
                reset_property MANUAL_ROUTING $site
                set should_reset 0
            }
        }
        remove_cell [get_cells *]
    }

    #VCC and GND cells are not placeable, but we still want to include them in our xml file
    dict set cell_site_map "VCC" [list]
    dict set cell_site_map "GND" [list]
    return $cell_site_map
}

#
proc processLeafCell {c s fo} {
    create_net tmp_net
    foreach b [get_bels -of $s] {
        if { [is_my_placement_legal $c $b] == 1 } then {
            puts $fo "        <bel>"
            puts $fo "          <id>"
            puts $fo "            <primitive_type>[tincr::sites::get_type $s]</primitive_type>"
            puts $fo "            <name>[suffix $b "/"]</name>"
            puts $fo "          </id>"

            #if the placement is legal, place the cell onto the bel to get pin mapping info
            place_cell $c $b

            #cell to bel pin name dictionary
            set pin_mappings [dict create]
            set unconnectedCellPins [list]

            #Populate the cell pin to bel pin mappings dictionary
            foreach cell_pin [get_pins -of $c] {
                set ref_name_cp [lindex [split $cell_pin "/"] end]

                #get the BEL pin to cell pin mapping
                set bel_pin [get_bel_pins -of $cell_pin -quiet]

                if {$bel_pin != "" } {
                    set ref_name_bp [lindex [split [get_property NAME $bel_pin] "/"] end]

                    #if the bel pin name does not match the cell pin name, then add it as a possible name
                    if { $ref_name_bp != $ref_name_cp } {
                        dict lappend pin_mappings $ref_name_cp $ref_name_bp
                    }
                } else {
                    set group [get_property PRIMITIVE_GROUP $c]
                    if {$group != "LUT" && $group != "INV" && $group != "BUF"} {
                        lappend unconnectedCellPins $cell_pin
                    } else {
                        #For LUT/INV/BUF primitives, a cell pin can map to multiple bel pins
                        #this code determines the valid mappings for each cell pin in these cases
                        foreach bp [get_bel_pins -of $b -filter {DIRECTION==IN} -quiet] {
                            set ref_name_bp [lindex [split [get_property NAME $bp] "/"] end]

                            if { [catch {[set_property LOCK_PINS "{$ref_name_cp:$ref_name_bp}" $c]} t] == 0 } {
                                dict lappend pin_mappings $ref_name_cp $ref_name_bp
                            }
                            reset_property LOCK_PINS $c
                        }
                    }
                }
            }

            # connect a net to each unconnected cell pin to see if this results in the cell pin being mapped to a bel pin
            # this was added for a special case of the CARRY4 BEL. When it is placed, two of its cell pins are not
            # mapped to bel pins (CI and CYINIT). However, when you connect a net to these pins, the mapping is created.
            # Since a carry4 cell is not a LUT,INV, or BUF, we cannot use the LOCK_PINS property to try and map the cell
            # pins onto bel pins

            foreach cell_pin $unconnectedCellPins {
                connect_net -net [get_nets tmp_net] -objects [get_pins $cell_pin]

                set bel_pin [get_bel_pins -of $cell_pin -quiet]

                if {$bel_pin != "" } {
                    set ref_name_bp [lindex [split [get_property NAME $bel_pin] "/"] end]
                    set ref_name_cp [lindex [split $cell_pin "/"] end]

                    if { $ref_name_bp != $ref_name_cp } {
                        dict lappend pin_mappings $ref_name_cp $ref_name_bp
                    }
                }
                disconnect_net -net [get_nets tmp_net] -objects [get_pins $cell_pin]
            }

            #print the pin mappings to the file
            if { [expr {[dict size $pin_mappings] > 0}] } {
                puts $fo "          <pins>"

                dict for {cp bp} $pin_mappings {
                    puts $fo "            <pin>"
                    puts $fo "              <name>$cp</name>"
                    foreach b_p $bp {
                        puts $fo "              <possible>$b_p</possible>"
                    }
                    puts $fo "            </pin>"
                }
                puts $fo "          </pins>"
            }

            puts $fo "        </bel>"
        }
    }
    unplace_cell $c
    remove_net [get_nets tmp_net]
}

#
proc writeMacroXML {c s fo} {
    puts $fo "        <bel>"
    puts $fo "          <id>"
    puts $fo "            <primitive_type>[tincr::sites::get_type $s]</primitive_type>"
    puts $fo "            <name>[suffix [get_property BEL $c] "."]</name>"
    puts $fo "          </id>"

    puts $fo "          <bel_mappings>"

    foreach bel [get_bels -of $s -filter {IS_USED==1}] {
        puts $fo "            <name>[suffix $bel "/"]</name>"
    }

    puts $fo "          </bel_mappings>"
    puts $fo "          <pin_mappings>"

    #get the cell pin to bel pin mappings
    foreach net [get_nets "$c/*"] {
        puts $fo "            <pin>"
        puts $fo "              <name>[suffix $net "/"]</name>"

        foreach bp [get_bel_pins -of $net -quiet] {
            puts $fo "              <mapping>"
            puts $fo "                <bel_name>[lindex [split $bp "/"] 1]</bel_name>"
            puts $fo "                <bel_pin>[suffix $bp "/"]</bel_pin>"
            puts $fo "              </mapping>"
        }
        puts $fo "            </pin>"
    }

    puts $fo "          </pin_mappings>"
    puts $fo "        </bel>"
}

#
proc processMacroCell {c s fo} {
    set bel_cnt 0

    #first, try to place the MACRO cell onto each BEL of the site
    foreach b [get_bels -of $s] {
        if { [is_my_placement_legal $c $b] == 1 } then {
            incr bel_cnt
            place_cell $c $b
            writeMacroXML $c $s $fo
            unplace_cell $c
        }
    }

    # If i can't place the cell onto any of the BELS, than place it on the site itself
    if { $bel_cnt == 0 } {
        place_cell $c $s
        writeMacroXML $c $s $fo
        unplace_cell $c
    }
}

proc doPorts { fo } {

    puts "Doing ports..."

    set lc [get_lib_cells]
    set dict [uniqueSites]

    puts $fo "    <cell>"
    puts $fo "      <type>IPORT</type>"
    puts $fo "          <is_port/>"
    puts $fo "      <level>LEAF</level>"
    puts $fo "      <pins>"
    puts $fo "        <pin>"
    puts $fo "          <name>PAD</name>"
    puts $fo "          <direction>output</direction>"
    puts $fo "        </pin>"
    puts $fo "      </pins>"
    puts $fo "      <bels>"
    
    dict for {type site} $dict {
        set b [get_bels -of $site]
        set ispad 0
        foreach b [get_bels -of $site] {
            if { [get_property TYPE $b] == "PAD" } {
                if { [get_property NUM_OUTPUTS $site] > 0 } {
                    puts $fo "        <bel>"
                    puts $fo "          <id>"
                    puts $fo "            <primitive_type>$type</primitive_type>"
                    puts $fo "            <name>[suffix [get_property NAME $b] "/"]</name>"
                    puts $fo "          </id>"
                    puts $fo "        </bel>"
                }
            }
        }
        
    }
    puts $fo "      </bels>"
    puts $fo "    </cell>"

    puts $fo "    <cell>"
    puts $fo "      <type>OPORT</type>"
    puts $fo "          <is_port/>"
    puts $fo "      <level>LEAF</level>"
    puts $fo "      <pins>"
    puts $fo "        <pin>"
    puts $fo "          <name>PAD</name>"
    puts $fo "          <direction>input</direction>"
    puts $fo "        </pin>"
    puts $fo "      </pins>"
    puts $fo "      <bels>"
    
    dict for {type site} $dict {
        set b [get_bels -of $site]
        set ispad 0
        foreach b [get_bels -of $site] {
            if { [get_property TYPE $b] == "PAD" } {
                if { [get_property NUM_INPUTS $site] > 0 } {
                    puts $fo "        <bel>"
                    puts $fo "          <id>"
                    puts $fo "            <primitive_type>$type</primitive_type>"
                    puts $fo "            <name>[suffix [get_property NAME $b] "/"]</name>"
                    puts $fo "          </id>"
                    puts $fo "        </bel>"
                }
            }
        }
        
    }
    puts $fo "      </bels>"
    puts $fo "    </cell>"

    puts $fo "    <cell>"
    puts $fo "      <type>IOPORT</type>"
    puts $fo "          <is_port/>"
    puts $fo "      <level>LEAF</level>"
    puts $fo "      <pins>"
    puts $fo "        <pin>"
    puts $fo "          <name>PAD</name>"
    puts $fo "          <direction>inout</direction>"
    puts $fo "        </pin>"
    puts $fo "      </pins>"
    puts $fo "      <bels>"
    
    dict for {type site} $dict {
        set b [get_bels -of $site]
        set ispad 0
        foreach b [get_bels -of $site] {
            if { [get_property TYPE $b] == "PAD" } {
                if { [get_property NUM_INPUTS $site] > 0 && [get_property NUM_OUTPUTS $site] > 0 } {
                    puts $fo "        <bel>"
                    puts $fo "          <id>"
                    puts $fo "            <primitive_type>$type</primitive_type>"
                    puts $fo "            <name>[suffix [get_property NAME $b] "/"]</name>"
                    puts $fo "          </id>"
                    puts $fo "        </bel>"
                }
            }
        }
        
    }
    puts $fo "      </bels>"
    puts $fo "    </cell>"
}

#top level function used to create a cell library file used in RapidSmith2
proc ::tincr::createCellLibrary { {part xc7a100t-csg324-3} {filename ""} } {

    set part_list [split $part "-"]

    if {$filename == ""} {
        set filename "cellLibrary_[lindex $part_list 0][lindex $part_list 1].xml"
    }

    set fo [open $filename w]

    #open empty design to gain access to the Vivado cell library
    createBlankDesignByPart $part

    #find all of the supported library cells in the current part
    puts "\nFinding all of the supported cells in the current part..."
    set supported [getSupportedLibCells]

    #generate a map of lib_cells -> sites that instances of this cell can be placed on
    puts "Getting a handle to each unique primitive site..."
    set dict [uniqueSites]

    puts "Finding all valid site placements for each supported cell...\n"
    set cellsandsites [createCellToSiteMap $supported $dict]

    #write the cell library xml file header
    puts $fo {<?xml version="1.0" encoding="UTF-8"?>}
    puts $fo "<root>"
    puts $fo "  <cells>"

    set cnt 0

    #create the xml for each valid library cell
    dict for {cname sitenames} $cellsandsites {
        incr cnt

        set libcell [get_lib_cells $cname -quiet]
        set c [create_cell -reference $libcell "brent_$cnt" -quiet]
        set level [get_property PRIMITIVE_LEVEL $c]

        puts "Processing: $cname"

        puts $fo "    <cell>"
        set cname [get_property NAME $libcell]
        puts $fo "      <type>$cname</type>"

        # Mark LUT cells
        if { [string first "LUT" $cname] == 0 } {
            puts $fo "        <is_lut>"
            set num [string range $cname 3 100]
            puts $fo "          <num_inputs>$num</num_inputs>"
            puts $fo "        </is_lut>"
        }
        
        # Mark VCC and GND cells
        if { $cname == "VCC" } {
            puts $fo "          <vcc_source></vcc_source>"
        }
        if { $cname == "GND" } {
            puts $fo "          <gnd_source></gnd_source>"
        }

        
        puts $fo "      <level>$level</level>"
        puts $fo "      <pins>"

        #print the cell pin information
        foreach p [get_pins -of $c] {
            puts $fo "        <pin>"
            puts $fo "          <name>[get_property REF_PIN_NAME $p]</name>"

            set dir [get_property DIRECTION $p]
            if { $dir == "IN" } then {
                puts $fo "          <direction>input</direction>"
            } else {
                puts $fo "          <direction>output</direction>"
            }

            puts $fo "        </pin>"
        }
        puts $fo "      </pins>"

        puts "Sitenames = $sitenames\n"
        puts $fo "      <bels>"

        #print the placement information
        foreach sn $sitenames {
            set s [dict get $dict $sn]

            # We only need to set the type of a site if it is an alternate type only (and not also a default type).
            # For IOB sites, setting the MANUAL_ROUTING property causes incorrect behavior for example, you can no longer:
            #  (a) Place cells anywhere on the site
            #  (b) Query the site for objects such as site pins (this will crash Vivado)
            # Therefore, the code below was modified to only set the site type if we are not working with an IOB site.
            # We skip setting slice types as well, because carry4 cells can no longer be placed without an error.
            # this is not a big deal because we know each slice type will occur as a default type
            if { [regexp {.*IOB*} $sn] == 0 && [regexp {.*SLICE*} $sn] == 0 } {
                reset_property MANUAL_ROUTING $s
                tincr::sites::set_type $s $sn
            }

            if {$level == "macro"} {
                # processMacroCell $c $s $fo
            } else {
                processLeafCell $c $s $fo
            }
        }
        puts $fo "      </bels>"
        puts $fo "    </cell>"
        puts $fo ""
    }

    doPorts $fo
    
    puts $fo "  </cells>"
    puts $fo "</root>"

    close $fo
#    close_design

    puts "CellLibrary \"$filename\" created successfully!"
}

#test code

#set libCell [getSupportedLeafLibCells]
#set sites [uniqueSites

#function call to generate the cell library file
#createCellLibrary xc7a100t-csg324-3

# Notes
# ------

# - Currently RapidSmith2 only supports assigning a cell pin to a single bel pin...in Vivado, this is not the case
#       A macro cell pin can map to several different bel pins. Take a LUTRAM cell for example, the address pins can
#       be shared across all 4 LUTs, but they all map back to one cell pin for each address pin.
#       So, in the XML output a different tag is used to represent these (as opposed to the possible tag).

# - I have made a decision...CIN will now only map to CYINIT of the carry 4 in RapidSmith2
#       This is because only either CIN or CYINIT will be used, not both. We can just include in the
#       documentation this fact, and if you are designing in rapidSmith2, only map one to the CYINIT

# - an XML template of the cellLibrary has been created, that can be found in the file macro_xml_template.xml
