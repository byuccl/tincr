package provide tincr.io.design 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        run_rapidsmith_command
}

## Executes a command send from a running instance of RapidSmith. The "rs_start" and "rs_end"
#   are used to communicate with RapidSmith when the command has started or completed.
#
proc ::tincr::run_rapidsmith_command { cmd } {
    puts "rs_start"
    {*}$cmd
    puts "rs_end"
} 

## Tests if the specified bel is a routethrough under a certain configuration. Specifically, 
#   this function checks that [get_property CONFIG.EQN]="(expected_outpin)=(expected_inpin)"
#
# @param bel Name of a bel
# @param expected_inpin Expected input pin of the routethrough
# @param expected_outpin Expected output pin of the routethrough
# @return 1 if the bel matches the expected pattern, 0 otherwise
proc ::tincr::test_routethrough { bel expected_inpin expected_outpin } {
    
    set config [get_property CONFIG.EQN [get_bels $bel]]
    
    if {![regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(+(A[1-6])\)+ ?} $config -> actual_outpin actual_inpin]} {
       puts 0
    }    
    
    if { $actual_outpin != $expected_outpin || $actual_inpin != $expected_inpin} {
        puts "0\n$expected_inpin\n$actual_inpin\n$expected_outpin\n$actual_outpin\n"
    }
    
    puts 1
}

## Test that the specified Bel is a static source bel (i.e. the configuration equation is 0 or 1).
#
# @param bel Name of a bel
# @return 1 if the bel is a static source, 0 otherwise
proc ::tincr::test_static_sources { bel } {
    
    set config [get_property CONFIG.EQN [get_bels $bel]]
    
    if {[regexp {(O[5,6])=(?:\(A6\+~A6\)\*)?\(?[0,1]\)? ?} $config -> pin] } {
        puts 1
    }
    puts 0
}

## Prints the values of the properties in {@code property_list} for the specified cell. 
#   The properties are printed in the following format: <br>
#    "propertyName1 propertyValue1\n" <br>
#    "propertyName2 propertyValue2\n" <br>
#     ...
#
#   This function is used to verify cell properties in RapidSmith
# @param cell Name of a cell
# @param property_list list of property names
proc ::tincr::report_property_values {cell property_list} {
    
    set cell [get_cells $cell]
    
    set return_string ""
    foreach property $property_list {
        set return_string "$return_string$property![get_property $property $cell]\n"
    }
    
    puts -nonewline $return_string
}

## Prints the placement information of a cell to standard out in the following format: <br>
#   (1) sitename/belname ; what bel the cell is placed on <br>
#   (2) cellpin1 belpin1 belpin2 ; the cell pin to bel pin mappings for a cell pin <br>
#   (3) cellpin2 belpin1 belpin2 ; <br> 
#   ... <br>
#
#   This function is used to verify that a cell has been imported into RapidSmith correctly.Used for testing that cell of a design have been imported correctly
#
# @param cell Name of the cell to  
proc ::tincr::report_cell_placement_info {cell} {
   
    set cell [get_cells $cell]
    
    # Get what bel the cell is placed on
    if {[get_property STATUS $cell] == "UNPLACED"} {
        set returnString "\n"
    } else {
        set site [get_sites -of $cell]
        set belPlacement [lindex [split [get_bels -of $cell -quiet] "/"] end]
    
        if { [get_property IS_PAD $site] } {
            set site [get_property NAME [get_package_pins -quiet -of_object $site]]
        }
        set returnString "$site/$belPlacement\n"
    }
    
    # populate the pin mappings for each cell pin of the cell
    foreach pin [get_pins -of [get_cells $cell]] {
        set returnString "$returnString[get_property REF_PIN_NAME $pin] [get_bel_pins -of $pin -quiet]\n"
    }
    
    puts -nonewline $returnString
}

## Prints the wires, cell pins, and bel pins of the net to standard out in the following format: <br>
#
#   "wire1 wire2 ... \n" <br>
#   "pin1 pin2 ... pin3" <br>
#   "belpin1 belpin2 ... belpin3" <br>
#
#   This function is used to verify that a net has been imported correctly into RapidSmith
#
proc ::tincr::report_physical_net_info {net} {
    
    set net [get_nets $net]
    
    set wires [get_wires -of $net -quiet]
    set cell_pins [get_pins -of $net -quiet]
    set bel_pins [create_bel_pin_string $net]
    
    puts "$wires\n$cell_pins\n$bel_pins"
}

## Scans through the attached bel pins of the specified net, and replaces any IOB site
#   names with the PACKAGE_PIN name of the site. This is to match RapidSmith.
#
# @param Name of a net
# @return a list of bel pins connected to the net with site pin names adjusted.
proc create_bel_pin_string {net} {
    set bel_pin_string ""
    foreach bel_pin [get_bel_pins -of $net -quiet] {
        set bel_pin_toks [split $bel_pin "/"]
        set site [get_sites [lindex $bel_pin_toks 0]]
        
        if { [get_property IS_PAD $site] } {
            set site [get_property NAME [get_package_pins -quiet -of_object $site]]
        }
        
        set bel_pin_string "$bel_pin_string$site/[lindex $bel_pin_toks 1]/[lindex $bel_pin_toks 2] "
    }
    return $bel_pin_string
}

## Prints the wires, cell pins, and bel pins of ALL VCC nets in the currently opened design
#   The output format is the same as {@link ::tincr::get_physical_net_info}
proc ::tincr::report_vcc_routing_info {} {
    
    set vcc_nets [get_nets -filter {TYPE==POWER}]
    
    set num_vcc_cells [llength [get_cells -filter {REF_NAME==VCC}]]
    set vcc_wires [get_wires -of $vcc_nets -quiet]
    set vcc_cell_pins [get_pins -of $vcc_nets -quiet]
    set vcc_bel_pins [get_bel_pins -of $vcc_nets -quiet]
        
    puts "$vcc_wires\n$num_vcc_cells\n$vcc_cell_pins\n$vcc_bel_pins"
}

## Prints the wires, cell pins, and bel pins of ALL GND nets in the currently opened design
#   The output format is the same as {@link ::tincr::get_physical_net_info}
proc ::tincr::report_gnd_routing_info {} {
    
    set num_gnd_cells [llength [get_cells -filter {REF_NAME==GND}]]
    set gnd_nets [get_nets -filter {TYPE==GROUND} -quiet]
    set gnd_wires [get_wires -of $gnd_nets -quiet]
    set gnd_cell_pins [get_pins -of $gnd_nets -quiet]
    set gnd_bel_pins [get_bel_pins -of $gnd_nets -quiet]
    
    puts "$gnd_wires\n$num_gnd_cells\n$gnd_cell_pins\n$gnd_bel_pins"
}

## Returns the number of used sites in the currently opened design
#
proc ::tincr::report_used_site_count {} {
    puts [llength [get_sites -filter IS_USED -quiet]]
}

## Prints the used site pips for the specified site to standard out
#   This function is used to verify that site pips in RapidSmith were imported correctly.
#
# @param site Name of a site
#
proc ::tincr::report_used_site_pips { site } {
    
    set site [get_sites $site -quiet]
    
    puts "[get_property IS_USED $site]\n[get_site_pips -of $site -filter {IS_USED} -quiet]"
}
 
## Tests that a the specified cell has only the default values for each configurable property
#   This function is used to verify that cells in RapidSmith with no properties have all default properties.
#
# @param Name of a cell
proc ::tincr::test_default_cell {cell} {
    set cell [get_cell $cell]
    set lib_cell [get_lib_cell -of $cell]
    
    foreach property [list_property $lib_cell] {
       
        # look for the CONFIG properties that have default values
        if { [regexp {CONFIG\.([^\.]+)\.DEFAULT$} $property -> match] } {
            set cell_property [get_property $match $cell]
            set default_property [get_property $property $lib_cell]
            if {$cell_property != "" && $cell_property != $default_property} {
                puts $property
                puts "0\n$match\n$cell_property\n$default_property"
                return
            }
        }
    }
    puts 1
}

## Tests that the placement of the port with the given name matches 
#   the expected port placement
#
# @param port Name of the port to test
# @param expected_port_loc expected site location of the port
#
proc ::tincr::test_port_placement {port expected_port_loc} {
    set test_passed 1
    
    set expected_port_loc [get_sites $expected_port_loc]
    set actual_port_loc [get_property LOC [get_ports $port]]
    
    if {$actual_port_loc != $expected_port_loc} {
        set test_passed "0\n$expected_port_loc\n$actual_port_loc\n"
    }
    
    puts $test_passed
}
