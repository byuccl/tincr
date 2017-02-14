package provide tincr.io.library 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        create_xml_cell_library \
        test_cell_library \
        write_macro_xml
}

# This script creates the cellLibrary.xml file needed for RapidSmith2.

## Creates a dictionary that maps a cell object, to all site locations where it
#   can be validly placed.
#
# @param lib_cells List of supported library cells for the current device
# @param site_map Dictionary mapping site types, to site locations
# @param alternate_site_set Set of sites that are only alternate sites
# @return A dictionary that maps a cell to all sites it can be placed on
proc create_cell_to_site_map {lib_cells site_map alternate_site_set} {
    
    set cell_site_map [dict create]
    
    foreach lib_cell $lib_cells {
        
        set cell_instance [create_cell -reference $lib_cell tmp -quiet]
        
        # try to place each lib_cell on each default site
        dict for {sitename site} $site_map {
            
            # set the manual routing property for a site ONLY IF the site type is an alternate only 
            set is_alternate 0
            if { [::struct::set contains $alternate_site_set $sitename] } {
                set is_alternate 1
                set_property MANUAL_ROUTING $sitename $site 
            }
            
            if {[catch {[place_cell $cell_instance $site]} err] == 0} {
                dict lappend cell_site_map $lib_cell $sitename
                unplace_cell $cell_instance
            }
            
            if { $is_alternate } {
                reset_property MANUAL_ROUTING $site
            }
        }
        
        # Print all unsupported lib cells for the part (this is for debugging)
        if { $::tincr::debug && ![dict exists $cell_site_map $lib_cell] } {
            puts "\[Warning\] Library Cell: $lib_cell not supported for the current part. Please Review"
        }
        
        remove_cell $cell_instance -quiet
    }
    
    #VCC and GND cells are not place-able, but we still want to include them in our XML file
    dict set cell_site_map [get_lib_cells VCC] [list]
    dict set cell_site_map [get_lib_cells GND] [list]
        
    return $cell_site_map
}

## Creates the cell library XML for a leaf cell
#
# @param cell Instance of a library cell to process
# @param site Site location to place the cell on
# @param xml_out Output file to print the XML to
#
proc process_leaf_cell {cell site xml_out} {
  
    # create_net tmp_net
    set cell_group [get_property PRIMITIVE_GROUP $cell]
    set cell_can_permute_pins [expr {$cell_group == "LUT" || $cell_group == "INV" || $cell_group == "BUF"}] 
    
    # Find all of the configurations of the cell : TODO: add this at a later date
    if {$::tincr::debug} {
        set config_list [list]
        set config_value_map [dict create]
        set value_count [get_configurations $cell config_list config_value_map]
    
        set has_configs [expr {[llength $config_list] > 0}]
        global config_threshold
        set above_threshold [expr {$value_count > $config_threshold}]
    
        puts "Config count: [llength $config_list] Value count: $value_count"
    }
    
    foreach bel [get_bels -of $site] {
        if { [tincr::cells::is_placement_legal $cell $bel] == 1 } then {
            puts $xml_out "        <bel>"
            puts $xml_out "          <id>"
            puts $xml_out "            <site_type>[tincr::sites::get_type $site]</site_type>"
            puts $xml_out "            <name>[tincr::suffix $bel "/"]</name>"
            puts $xml_out "          </id>"

            #if the placement is legal, place the cell onto the bel to get pin mapping info
            # place_cell $cell $bel
            # set unconnectedCellPins [list]

            # create a dictionary of cell pin to BEL pin mappings
            if {$cell_can_permute_pins} {
                # set pin_map [create_leaf_cell_pin_mapping_permutable $cell $bel]
                create_leaf_cell_pin_mapping_permutable $cell $bel $xml_out
            } else {
                get_static_leaf_cell_pin_mappings $cell $bel $xml_out
            }
            
            # The commented out sections below if for when configurable cell mappings are added to RapidSmith
            # for now they are commented out because they are not used, but will be used sometime in the near future.
            if {0} { ; # START COMMENT
            else {
                                
                # If the cell has no configs or the # of configs are above the maximum threshold, 
                # call the static cell pin function
                if { !$has_configs || $above_threshold } {
                    get_static_leaf_cell_pin_mappings $cell $bel $xml_out
                } else { ; # otherwise, call the dynamic function
                    # TODO: create a dictionary here?
                    get_dynamic_leaf_cell_pin_mappings $cell $bel $config_list $config_value_map $xml_out
                }
            }
            } ; # END COMMENT
            
            puts $xml_out "        </bel>"
        }
    }
    unplace_cell $cell
    # remove_net [get_nets tmp_net]
}

## Gets the cell pin to bel pin mappings for a cell that DOES NOT have 
#   configurable pin mappings (i.e. don't change based on how it is configured).
#   Writes these pin mappings to the specified XML file.
#
# @param cell Cell instance
# @param bel Bel to place the cell on
# @param xml_out File handle to write the pin mapping XML
proc get_static_leaf_cell_pin_mappings { cell bel xml_out } {
    
    place_cell $cell $bel
    attach_nets $cell
    
    set pin_map [dict create]
    set unconnected_pins [list]
    foreach cell_pin [get_pins -of $cell] {
        
        set mapped_bel_pins [get_bel_pins -of $cell_pin -quiet]
        
        if {[llength $mapped_bel_pins] == 0 } {
            lappend unconnected_pins $cell_pin
        } else {
        
            if { $::tincr::debug &&  [llength $mapped_bel_pins] > 1 } {
                puts "# Multiple Mappings: [get_lib_cells -of $cell -quiet] $cell_pin"
            }
            dict set pin_map $cell_pin [list]
            foreach bel_pin $mapped_bel_pins {
                dict lappend pin_map $cell_pin $bel_pin
            }
        }
    }
    
    remove_net * -quiet
    
    foreach cell_pin $unconnected_pins {
        set net [create_net tmp]
        connect_net -net $net -objects $cell_pin
        set mapped_bel_pins [get_bel_pins -of $cell_pin -quiet]

        dict set pin_map $cell_pin [list]
        foreach bel_pin $mapped_bel_pins {
            dict lappend pin_map $cell_pin $bel_pin
        }
        
        remove_net $net
    }
    
    unplace_cell $cell
    
    write_possible_pin_mappings $pin_map $xml_out
    # write_pin_mappings $cell [list $pin_map] [list "DEFAULT"] $xml_out
}

## Creates and attaches a unique net to each pin of the specified cell. This function
#   is used to get more accurate pin mappings while placing cells onto Bels
#
# @param cell Library cell instance
proc attach_nets {cell} {

    set count 0
    foreach pin [get_pins -of $cell] {
        set net [create_net "tmp$count"]
        connect_net -net $net -objects $pin -quiet
        incr count
    }
}

## Gets the cell pin to bel pin mappings for a cell whose mappings are dependent
#   on the cell's current configuration. Writes these pin mappings to the specified XML file.
#   TODO: Use this function once RapidSmith supports configurable pin mappings.
#   TODO: Update this function to support any number of configuration combinations
#
# @param cell Library cell instance
# @param bel Bel object to place the cell on
# @param config_list List of configurations that could affect the pin mapping
# @param config_value_map Dictionary containing the possible values for each configuratoin in config_list
# @param xml_out File handle to write the pin mapping XML
proc get_dynamic_leaf_cell_pin_mappings { cell bel config_list config_value_map xml_out } {
    
    set config_count [llength $config_list]
   
    tincr::cells::reset_configuration $cell $config_list
    # attach_nets $cell
            
    set pin_map_list [list]
    set configuration_settings [list "DEFAULT"]

    set default_mappings [get_unique_pin_mappings $cell $bel $pin_map_list]
    
    ::tincr::assert {[dict size $default_mappings] > 0} 
    lappend pin_map_list $default_mappings
    
    # Change one configuration at a time, and see how it changes the pin mappings against the default
    # If the default pin mappings are changed, 
    dict for {config value_list} $config_value_map {
        
        foreach value $value_list {
            
            set_property $config $value $cell
            set pin_map [get_unique_pin_mappings $cell $bel [list $default_mappings]]
            if { [dict size $pin_map] > 0 } { ; # i.e. new mappings are found
                lappend pin_map_list $pin_map
                lappend configuration_settings "$config:$value"
            }
            set_property $config [tincr::cells::get_default_value $cell $config] $cell
        }
    }
    
    # Now, change two configurations at a time, and compare them against all single instance changes
    # To determine if multiple configurations can work together to change the pin mappings
    for { set i 0 } { $i < $config_count } { incr i } {
        set config [lindex $config_list end] ; # grab the last config element
        set config_list [lreplace $config_list end end] ; # remove it from the list
        
        foreach value [dict get $config_value_map $config] {
            set_property $config $value $cell
            
            foreach other_config $config_list {
                foreach other_value [dict get $config_value_map $other_config] {
                    set_property $other_config $other_value $cell
                    set pin_map [get_unique_pin_mappings $cell $bel $pin_map_list]
                    if { [dict size $pin_map] > 0 } { ; # i.e. new mappings are found
                        # puts "Found new mapping!"
                        lappend pin_map_list $pin_map
                        lappend configuration_settings "$config:$value $other_config:$other_value"
                    }
                    set_property $other_config [tincr::cells::get_default_value $cell $other_config] $cell
                }
            }
            
            set_property $config [tincr::cells::get_default_value $cell $config] $cell
        }
        
        linsert $config_list 0 $config ; # add the processes element to the start of the list
    }
    
    # Print the conditional configurations to the file
    write_pin_mappings $cell $pin_map_list $configuration_settings $xml_out
    
    # remove all of the temporarily created nets
    # remove_net *
}

## Gets all configurations on the specified cell that could possible affect cell pin to 
#   bel pin mappings. Only configurations with discrete values are returned.
#   TODO: rename this to be more descriptive?
#
# @param cell Library cell instance
# @param config_lst Reference list that will be populated to include
#           all important configurations on the cell. In general, you should
#           pass an empty list into this function.   
# @param config_mp Reference dictionary that will be populated with a 
#           a map from configuration to all possible values for that config.
#           In general, an empty dictionary should be passed into this function
proc get_configurations { cell config_lst config_mp } {
    
    upvar $config_lst config_list
    upvar $config_mp config_map
    set lib_cell [get_lib_cells -of $cell]
    
    set value_count 0
    
    foreach property [list_property $lib_cell] {
    
        # look for the CONFIG properties that have default values
        if { [regexp {CONFIG\.([^\.]+)\.DEFAULT$} $property -> match] } {
            
            # filter out configurations for simulation or with non-discrete ranges
            if { ![string match "*SIM*" $match] && ![string match "min*" [get_property "CONFIG.$match.VALUES" $lib_cell]] } {
                
                # split the values on whitespaces
                set value_list [regexp -all -inline {\S+} [get_property "CONFIG.$match.VALUES" $lib_cell]]

                set default_value [get_property $property $lib_cell]
                if {[catch {set_property $match $default_value $cell} fid] == 1} {
                    if {$::tincr::debug} {
                        puts "\[Warning\] Property $match cannot be set on library cell $lib_cell in the TCL interface. This property might affect pin mappings."
                    }
                } elseif { [llength $value_list] > 0 } {              
                    # add the values to the value map
                    foreach value $value_list  {
                        dict lappend config_map $match [string trim $value ","]
                    }
                    
                    lappend config_list $match
                    incr value_count [llength $value_list]
                }
            }
        }
    }

    return $value_count
}

## Returns a dictionary of new pin mappings after the configurations of a cell
#   have been changed. Only pin mappings that have changed are included. 
#
# @param cell Library cell instance
# @param bel Bel object to place the cell on
# @param pinmap_list A list of pin mappings for all configurations already tested
# @return a dictionary of pin mappings that have been changed
proc get_unique_pin_mappings { cell bel pinmap_list } {
    
    set new_mappings [dict create]
    
    # place the cell and then attach a net to all of the pins
    place_cell $cell $bel
    
    set tmp_net [create_net tmp]
    # attach_nets $cell
    
    foreach pin [get_pins -of $cell] {
    
        set mapped_bel_pins [get_bel_pins -of $pin -quiet] 
        
        if {[llength $mapped_bel_pins] == 0} {
            #puts "Unconnected Net found!"
            connect_net -net $tmp_net -objects $pin
            set mapped_bel_pins [get_bel_pins -of $pin -quiet]
            disconnect_net -objects $pin
        }
        
        set exists 0
        foreach dictionary $pinmap_list {
            if { [dict exists $dictionary $pin] } {
                set mapping [dict get $dictionary $pin]
                if { $mapping == $mapped_bel_pins} {
                    set exists 1
                    break
                }
            }
        }
        
        # we found a new pin mappings based on the current configuration
        if {!$exists} {
            dict set new_mappings $pin $mapped_bel_pins
        }
    }
    
    unplace_cell $cell
    remove_net $tmp_net
    # remove_net *
    return $new_mappings
}

## Writes the cell pin to bel pin mappings to the specified output folder
#   using the "possible" keyword. Currently, possible can either mean permutable
#   pins, or multiple pin mappings.
#   TODO: update this once configurable pin mappings are supported in RapidSmith
#
# @param pin_map Dictionary from cell pin -> list of bel pins
# @param xml_out File handle to the output XML file
proc write_possible_pin_mappings { pin_map xml_out } {

    if { [dict size $pin_map] > 0 } {
        puts $xml_out "          <pins>"
    
        dict for {cell_pin bel_pin_list} $pin_map {
            puts $xml_out "            <pin>"
            puts $xml_out "              <name>[get_property REF_PIN_NAME $cell_pin]</name>"
            
            if { [llength $bel_pin_list] == 0 } {
                puts $xml_out "              <no_map/>"
            } else {
                foreach bel_pin $bel_pin_list {
                    puts $xml_out "              <possible>[lindex [split $bel_pin "/"] end]</possible>"
                }
            }
            puts $xml_out "            </pin>"
        }
        puts $xml_out "          </pins>"
    }    
}

## Writes configurable pin mappings to the specified output file using the "conditional_map"
#   convention. Currently, this function is not being used, but may be used in the future.
#   TODO: revisit this once configurable pin mappings are supported in RapidSmith.
#
# @param cell Library cell instance
# @param pin_map_list List of configurable pin mappings. The first pin mapping in the list
#           should be the default pin mappings.
# @param configuration_settings List of configurations for each corresponding pin_map
# @param xml_out File handle to the output XML file
proc write_pin_mappings { cell pin_map_list configuration_settings xml_out } {

    foreach pin [get_pins -of $cell] {
        
        puts $xml_out "          <pin>"
        puts $xml_out "            <name>[lindex [split $pin "/"] end]</name>"
        
        set count 0 
        foreach pin_map $pin_map_list {
        
            set config [lindex $configuration_settings $count]
            
            if { ![dict exists $pin_map $pin] } {
                incr count
                continue;
            }
            set mapped_bel_pins [dict get $pin_map $pin]
            
            if {$count == 0} {
                puts $xml_out "            <default_map>"
            } else {
                puts $xml_out "            <conditional_map>"
            }
            puts $xml_out "              <configuration>$config</configuration>"
            
            if { [llength $mapped_bel_pins] == 0} {
                puts $xml_out "              <no_map/>"
            } else {            
                foreach bel_pin $mapped_bel_pins {
                    puts $xml_out "              <map>[lindex [split $bel_pin "/"] end]</map>"
                }
            }
            
            if {$count == 0} {
                puts $xml_out "            </default_map>"
            } else {
                puts $xml_out "            </conditional_map>"
            }
            incr count
        }
        puts $xml_out "          </pin>"
    }
}

## Finds the cell pin to bel pin mappings for cells whose input pins are
#   permutable (i.e LUT cells). Prints the discovered mappings to the
#   specified output file.
#
# @param cell Library cell instance
# @param cell Bel to place the cell onto
# @param xml_out  File handle to the output XML file 
proc create_leaf_cell_pin_mapping_permutable {cell bel xml_out} {
    
    place_cell $cell $bel
    
    set pin_map [dict create]
    
    set input_bel_pin_names [list] 
    foreach input_bel_pin [get_bel_pins -of $bel -filter {DIRECTION==IN} -quiet] {
        lappend input_bel_pin_names [lindex [split [get_property NAME $input_bel_pin] "/"] end]
    }
    
    foreach cell_pin [get_pins -of $cell] {
        
        set is_input [expr {[get_property DIRECTION $cell_pin] == "IN"}]
       
        set cell_pin_name [lindex [split $cell_pin "/"] end]
        set bel_pins [get_bel_pins -of $cell_pin -quiet]
        
        if {$is_input} {
            ::tincr::assert { [llength $bel_pins] == 0 } "\[Assertion Error\] Input pin to permutable cell should have no default pin mapping $cell/$cell_pin_name [get_sites -of $cell]"
            foreach bel_pin_name $input_bel_pin_names {    
                
                if { [catch {[set_property LOCK_PINS "{$cell_pin_name:$bel_pin_name}" $cell]} err] == 0 } {
                    dict lappend pin_map $cell_pin_name $bel_pin_name
                }
                reset_property LOCK_PINS $cell
            }
        } else { ; # output cell pin
            ::tincr::assert { [llength $bel_pins] == 1 } "\[Assertion Error\] An output pin should map to exactly one bel pin. $cell/$cell_pin_name [get_sites -of $cell]"
            set bel_pin_name [lindex [split $bel_pins "/"] end]
            dict lappend pin_map $cell_pin_name $bel_pin_name
        }
        
        ::tincr::assert { [dict exists $pin_map $cell_pin_name] } "Cell Pin $cell/$cell_pin_name does not map to any bel pins"
    }
    
    write_pin_mappings $cell [list $pin_map] [list "DEFAULT"] $xml_out
    
    unplace_cell $cell
}

## Writes the cell library XML for a macro library cell. This functions is
#   currently not being used, but may be used in the future when/if macro cells
#   are supported in RapidSmith
#   TODO: revisit this if macro cells are supported in RapidSmith.
proc write_macro_xml_original {c s fo} {
    puts $fo "        <bel>"
    puts $fo "          <id>"
    puts $fo "            <site_type>[tincr::sites::get_type $s]</site_type>"
    puts $fo "            <name>[tincr::suffix [get_property BEL $c] "."]</name>"
    puts $fo "          </id>"

    puts $fo "          <bel_mappings>"

    foreach bel [get_bels -of $s -filter {IS_USED==1}] {
        puts $fo "            <name>[tincr::suffix $bel "/"]</name>"
    }

    puts $fo "          </bel_mappings>"
    puts $fo "          <pin_mappings>"

    #get the cell pin to bel pin mappings
    foreach net [get_nets "$c/*"] {
        puts $fo "            <pin>"
        puts $fo "              <name>[tincr::suffix $net "/"]</name>"

        foreach bp [get_bel_pins -of $net -quiet] {
            puts $fo "              <mapping>"
            puts $fo "                <bel_name>[lindex [split $bp "/"] 1]</bel_name>"
            puts $fo "                <bel_pin>[tincr::suffix $bp "/"]</bel_pin>"
            puts $fo "              </mapping>"
        }
        puts $fo "            </pin>"
    }

    puts $fo "          </pin_mappings>"
    puts $fo "        </bel>"
}

## Creates the cell library XML for a macro library cell
#   TODO: revisit this function if/when macro cells are supported in RapidSmith
#
# @param c Instance of a library cell to process
# @param s Site location to place the cell on
# @param fo Output file to print the XML to
proc process_macrocell {c s fo} {
    set bel_cnt 0

    #first, try to place the MACRO cell onto each BEL of the site
    foreach b [get_bels -of $s] {
        if { [tincr::cells::is_placement_legal $c $b] == 1 } then {
            incr bel_cnt
            place_cell $c $b
            write_macro_xml_original $c $s $fo
            unplace_cell $c
        }
    }

    # If i can't place the cell onto any of the BELS, than place it on the site itself
    if { $bel_cnt == 0 } {
        place_cell $c $s
        write_macro_xml_original $c $s $fo
        unplace_cell $c
    }
}

## Writes the cell library XML for a RapidSmith port cell.
#
# @param port_type Type of port (either IPORT, OPORT, or IOPORT)
# @param pin_direction Direction of the cell pin attached to the port 
# @param port_map Dictionary of site -> bel which this port can be placed
# @param xml_out File handle to the output XML file
proc write_port_xml { port_type pin_direction port_map xml_out } {
    # print the port header
    puts $xml_out "    <cell>"
    puts $xml_out "      <type>$port_type</type>"
    puts $xml_out "      <is_port/>"
    puts $xml_out "      <level>LEAF</level>"
    puts $xml_out "      <pins>"
    puts $xml_out "        <pin>"
    puts $xml_out "          <name>PAD</name>"
    puts $xml_out "          <direction>$pin_direction</direction>"
    puts $xml_out "        </pin>"
    puts $xml_out "      </pins>"
    puts $xml_out "      <bels>"
    
    # print the bel info for the port
    dict for {site_type bel_type} $port_map {
        puts $xml_out "        <bel>"
        puts $xml_out "          <id>"
        puts $xml_out "            <site_type>$site_type</site_type>"
        puts $xml_out "            <name>$bel_type</name>"
        puts $xml_out "          </id>"
        puts $xml_out "        </bel>"        
    }
    
    puts $xml_out "      </bels>"
    puts $xml_out "    </cell>"
}

## Searches through the currently open device, and finds all valid locations where
#   a RapidSmith port could be placed. Prints XML for each of these ports.
#
# @param site_map Dictionary mapping site type to a physical site location
# @param xml_out File handle to the output XML file
proc create_port_xml { site_map xml_out } {

    puts "Creating port definitions..."
    
    set iport_map [dict create]
    set oport_map [dict create]
    set ioport_map [dict create]
    
    # build the IPORT, OPORT, and IOPORT dictionaries
    dict for {type site} $site_map {
    
        if { [get_property IS_PAD $site] } {
        
            set num_inputs [get_property NUM_INPUTS $site]
            set num_outputs [get_property NUM_OUTPUTS $site]
            
            set is_output_pad [expr {$num_inputs > 0} ]
            set is_input_pad [expr {$num_outputs > 0} ]
            set is_inout_pad [expr {$num_inputs > 0 && $num_outputs > 0} ]
            
            foreach bel [get_bels -of $site -filter {TYPE=="PAD"}] {
                set bel_name [tincr::suffix [get_property NAME $bel] "/"]
                if {$is_input_pad} {
                    dict lappend iport_map $type $bel_name
                }
                if {$is_output_pad} {
                    dict lappend oport_map $type $bel_name
                }
                if {$is_inout_pad} {
                    dict lappend ioport_map $type $bel_name
                }
            }
        }
    }
    
    # write the port information to the xml file
    write_port_xml "IPORT" "output" $iport_map $xml_out
    write_port_xml "OPORT" "input" $oport_map $xml_out
    write_port_xml "IOPORT" "inout" $ioport_map $xml_out    
}

## For each configurable property on the specified library cell, this function writes: <br>
#   (1) The name of the property <br>
#   (2) The default value of the property <br>
#   (3) The max and min value of the property <br>
#   (4) The possible values of the property <br>
#   to the specified output file. It also includes any properties included in the
#   "readonly_properties" list which are not configurable.
#
# @param lib_cell Library cell
# @param xml_out File handle to the output XML file
proc write_property_xml { lib_cell xml_out } {

    set property_map [dict create]
    # TODO: This should be made a global variable at the top of the file (and set)
    # And, in the top level genCellLibrary, a list should be passed into the
    # function that specifies which properties the user wants. The default is what's below.
    set readonly_properties [list "PRIMITIVE_GROUP"]
    
    # create the set of readonly properties to include
    foreach readonly_prop $readonly_properties {
        ::struct::set add readonly_properties $readonly_prop
    }
        
    # create the dictionary that maps the configuration properties to the config options (default, min, max, etc.)
    foreach prop [list_property $lib_cell] {
        if { [regexp {CONFIG\.([^\.]+)\..*} $prop -> group] } { 
            dict lappend property_map $group $prop
        } elseif { [::struct::set contains $readonly_properties $prop ] } {
            dict set property_map $prop [list]
        }
    }
    
    # print the config map to the xml file (if there exists properties to print)
    # TODO: is it better to remove the CONFIG part of the property name?
    if { [dict size $property_map] > 0 } {
        puts $xml_out "      <libcellproperties>"
        dict for {config config_options} $property_map {
            puts $xml_out "        <libcellproperty>"
            puts $xml_out "          <name>$config</name>"
            
            if {[llength $config_options] == 0} { ; # it's a readonly property, can't be configured
                puts $xml_out "          <readonly/>"
                puts $xml_out "          <value>[get_property $config $lib_cell]</value>"
            } else { ; # its a config property      
                foreach prop $config_options {
                    set tag [string tolower [lindex [split $prop "."] 2]]
                    puts $xml_out "          <$tag>[get_property $prop $lib_cell]</$tag>"
                }
            }
            puts $xml_out "        </libcellproperty>"
        }
        puts $xml_out "      </libcellproperties>"
    }
}

## Writes the cell tags to the specified XML file. Cell tags mark
#   the cell to be unique in some way. These tags include is_lut,
#   vcc_source, gnd_source, and the primitive level of the cell. 
#   TODO: Add a permutable_pins tag?
#
# @param cell_instance Library cell instance 
# @param xml_out File handle to the output XML file
proc write_tag_xml { cell_instance xml_out } {
    set lib_cell [get_lib_cells -of $cell_instance]
    set lib_cell_name [get_property NAME $lib_cell]
    
    # Tag the type of the library cell
    puts $xml_out "      <type>$lib_cell_name</type>"

    # Tag LUT cells
    if { [get_property PRIMITIVE_GROUP $lib_cell] == "LUT" } {
        puts $xml_out "        <is_lut>"
        set num_pins [get_property NUM_PINS $lib_cell] 
        set num [expr {$num_pins - 1}]
        puts $xml_out "          <num_inputs>$num</num_inputs>"
        puts $xml_out "        </is_lut>"
    }
    
    # Tag VCC and GND cells
    if { $lib_cell_name == "VCC" } {
        puts $xml_out "        <vcc_source/>"
    }
    if { $lib_cell_name == "GND" } {
        puts $xml_out "        <gnd_source/>"
    }

    # Tag the primitive level (currently unused)
    puts $xml_out "      <level>[get_property PRIMITIVE_LEVEL $cell_instance]</level>"
}

## Writes the cell pin information to the specified XML file. 
#   The name, direction, and type (see {@link ::tincr::pins::get_pin_type}) is
#   printed for each pin.
#
# @param cell_instance Library cell instance
# @param xml_out File handle to the output XML file
proc write_pin_xml { cell_instance xml_out } {
    
    puts $xml_out "      <pins>"

    #print the cell pin information
    foreach cell_pin [get_pins -of $cell_instance] {
        puts $xml_out "        <pin>"
        puts $xml_out "          <name>[get_property REF_PIN_NAME $cell_pin]</name>"

        set dir [get_property DIRECTION $cell_pin]
        if { $dir == "IN" } then {
            puts $xml_out "          <direction>input</direction>"
        } elseif { $dir == "OUT" }  {
            puts $xml_out "          <direction>output</direction>"
        } else {
            puts $xml_out "          <direction>inout</direction>"
        }
        puts $xml_out "          <type>[tincr::pins::get_pin_type $cell_pin]</type>"

        puts $xml_out "        </pin>"
    }
    puts $xml_out "      </pins>"
}

## Generates the cell library XML for the specified cell when it is placed
#   on each site in the site list (each bel within the site is tested). Currently
#   ignores macro cells.
#   TODO: revisit if/when macro cells are supported in RapidSmith.
#
# @param cell_instance Library cell instance
# @param site_type_list List of site types to place cell_instance onto
# @param site_map Dictionary mapping site types to a physical site location
# @param alternate_only_sites Set of site types that are only alternate sites
# @param xml_out File handle to the output XML file
proc write_bel_placement_xml { cell_instance site_type_list site_map alternate_only_sites xml_out } {
    
    set lib_cell_name [get_property REF_NAME $cell_instance]
    puts $xml_out "      <bels>"

    set net_list [list]
        
    #print the placement information
    foreach site_type $site_type_list {
        set site [dict get $site_map $site_type]

        set is_alternate 0
        if { [::struct::set contains $alternate_only_sites $site_type] } {
            set is_alternate 1
            set_property MANUAL_ROUTING $site_type $site
        }
        
        # this will always be a leaf cell at this point
        process_leaf_cell $cell_instance $site $xml_out
        
        if { $is_alternate } {
            reset_property MANUAL_ROUTING $site
        }
    }
    
    puts $xml_out "      </bels>"
}

##
#
#
proc ::tincr::write_macro_xml {macro outfile} {

    set boundary_nets ""

    puts $outfile "    <macro>"
    puts $outfile "        <type>[get_property REF_NAME $macro]</type>"
    # print the macro internal cell information
    puts $outfile "        <cells>"
    foreach internal [get_cells $macro/*] {
        puts $outfile "            <internal>"
        puts $outfile "                <name>[lindex [split [get_property NAME $internal] "/"] 1]</name>"
        puts $outfile "                <type>[get_property REF_NAME $internal]</type>"
        puts $outfile "            </internal>"
    }
    puts $outfile "        </cells>"  
 
    # print the macro pin information
    puts $outfile "        <pins>"
    foreach pin [get_pins -of $macro] {
        puts $outfile "            <pin>"
        puts $outfile "                <name>[get_property REF_PIN_NAME $pin]</name>"
    
        # wrap this in a function call?
        set dir [get_property DIRECTION $pin]
        if {$dir == "IN"} {
            set dir "input"
        } elseif {$dir == "OUT"} {
            set dir "output"
        } else {
            set dir "inout"
        }
        puts $outfile "                <direction>$dir</direction>"
        puts $outfile "                <type>MACRO</type>"
        puts $outfile "                <internalConnections>"
    
        # Add the boundary net to the set of boundary nets. this should only return one object... add an assertion here?
        set internal_net [get_nets -boundary_type lower -of $pin]
        ::struct::set add boundary_nets $internal_net
    
        foreach internal [get_pins -of $internal_net -filter IS_LEAF] {
            set first [expr {[string first "/" $internal] + 1}]
            puts $outfile "                    <pinname>[string range $internal $first end]</pinname>"
        }
        puts $outfile "                </internalConnections>"
        puts $outfile "            </pin>"
    }
  
    puts $outfile "        </pins>"   
    
    # print the macro internal net structure  
    set macro_nets [get_nets $macro/*]
    set internal_nets [list]
    
    # check to see if some internal nets exist
    if {[::struct::set size $boundary_nets] != [llength $macro_nets]} {  
        puts $outfile "        <internalNets>"
        foreach net $macro_nets {
    
            # skip nets that connect to the macro boundary
            if {[::struct::set contains $boundary_nets $net]} {
                continue
            }
            
            set netname [lindex [split $net "/"] 1]
            lappend internal_nets $net
            puts $outfile "            <internalNet>"
            puts $outfile "                <name>$netname</name>"
            puts $outfile "                <pins>"
            foreach pin [get_pins -of $net] {
                set first [expr {[string first "/" $pin] + 1}]
                puts $outfile "                    <pinname>[string range $pin $first end]</pinname>"
            }   
    
            puts $outfile "                </pins>"
            puts $outfile "            </internalNet>"
        }
        puts $outfile "        </internalNets>"
    }
    
    puts $outfile "    </macro>"
    return $internal_nets
}


proc ::tincr::print_rapidSmith_license {outfile} {
    puts $outfile "<!--"
    puts $outfile " ~ Copyright (c) 2016 Brigham Young University"
    puts $outfile " ~ "
    puts $outfile " ~ This file is part of the BYU RapidSmith Tools."
    puts $outfile ""
    puts $outfile " ~ BYU RapidSmith Tools is free software: you may redistribute it"
    puts $outfile " ~ and/or modify it under the terms of the GNU General Public License "  
    puts $outfile " ~ as published by the Free Software Foundation, either version 3 of" 
    puts $outfile " ~ the License, or (at your option) any later version."
    puts $outfile " ~ "
    puts $outfile " ~ BYU RapidSmith Tools is distributed in the hope that it will be " 
    puts $outfile " ~ useful, but WITHOUT ANY WARRANTY; without even the implied warranty"
    puts $outfile " ~ of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the"
    puts $outfile " ~ GNU General Public License for more details." 
    puts $outfile " ~ "
    puts $outfile " ~ A copy of the GNU General Public License is included with the BYU RapidSmith"
    puts $outfile " ~ Tools. It can be found at doc/LICENSE.GPL3.TXT. You may" 
    puts $outfile " ~ also get a copy of the license at <http://www.gnu.org/licenses/>."
    puts $outfile " ~ -->"
}

## Creates a cell library XML file that can be used by RapidSmith version 2.0.
#
# @param filename Optional parameter to specify the generated cell library name. The default name is
#           "cellLibrary_part.xml"
# @param part Xilinx FPGA part to generate a cell library for
# @param threshold Threshold of configurable pin mappings to compute before quitting. (currently not used
#           but will be used in the future)
proc ::tincr::create_xml_cell_library { {part xc7a100t-csg324-3} {filename ""} {threshold 100}} {
    
    global config_threshold
    set config_threshold $threshold
    
    # create a valid filename if one is not specified
    if {$filename == ""} {
        set filename "cellLibrary_[get_parts $part].xml"
    } else { ; # add the xml extension if not specified
        set filename [::tincr::add_extension ".xml" $filename]
    }
    
    set xml_out [open $filename w]

    # print the RapidSmith 2.0 license to the file
    print_rapidSmith_license $xml_out
    
    # Open empty design to gain access to the Vivado cell library
    tincr::designs new mydes [get_parts $part]

    # Find all of the supported library cells in the current part
    puts "\nFinding all of the supported cells in the current part..."
    set supported_lib_cells [::tincr::get_supported_leaf_libcells]

    # Generate a map of lib_cells -> sites that instances of this cell can be placed on
    puts "Getting a handle to each unique primitive site..."
    set unique_sites [tincr::sites::unique 1]
    set site_map [lindex $unique_sites 0]
    set alternate_only_sites [lindex $unique_sites 1]

    puts "Finding all valid site placements for each supported cell...\n"
    set cell_to_sitetype_map [create_cell_to_site_map $supported_lib_cells $site_map $alternate_only_sites]
 
    # Write the cell library xml file header
    puts $xml_out {<?xml version="1.0" encoding="UTF-8"?>}
    puts $xml_out "<root>"
    
    # Add the family tag to the xml file  
    puts $xml_out "  <family>[string toupper [get_property FAMILY [get_parts -of [get_design]]]]</family>"
    
    puts $xml_out "  <cells>"

    # Create the xml for each valid library cell
    dict for {lib_cell_name site_type_list} $cell_to_sitetype_map {
        set lib_cell [get_lib_cells $lib_cell_name -quiet]
        set cell_instance [create_cell -reference $lib_cell "[string tolower $lib_cell_name]_tmp" -quiet]

        puts "Processing: $lib_cell_name"

        puts $xml_out "    <cell>"
        
        write_tag_xml $cell_instance $xml_out
        write_property_xml $lib_cell $xml_out 
        write_pin_xml $cell_instance $xml_out
        
        puts "Sitenames = $site_type_list\n"
        
        write_bel_placement_xml $cell_instance $site_type_list $site_map $alternate_only_sites $xml_out
        
        puts $xml_out "    </cell>"
        remove_cell $cell_instance -quiet
    }
    
    create_port_xml $site_map $xml_out
    
    puts $xml_out "  </cells>"
    
    # Create the xml for each macro cell supported in the device
    puts "Creating macro definitions..."
    set supported_macros [tincr::get_supported_macro_cells]
    
    if {[llength $supported_macros] > 0} {
        puts $xml_out "  <macros>"
        foreach macro_lib_cell $supported_macros {
            set macro_cell [create_cell -reference $macro_lib_cell "tmp" -quiet]
            tincr::write_macro_xml $macro_cell $xml_out
            remove_cell $macro_cell -quiet
        }

        puts $xml_out "  </macros>"
    }
    puts $xml_out "</root>"

    close $xml_out
    close_design -quiet

    puts "CellLibrary \"$filename\" created successfully!"
}

## Function to test the <code>create_xml_cell_library</code> function with assertions
# and debugging enabled. 
#
# @param part Xilinx FPGA part
proc ::tincr::test_cell_library { {part xc7a100t-csg324-3} } {
    set ::tincr::enable_assertions 1
    set ::tincr::debug 0
    
    ::tincr::create_xml_cell_library $part "test_cell_library.xml"
    
    set ::tincr::enable_assertions 0
    set ::tincr::debug 0
}

# global_variables...default config threshold
set config_threshold 100
