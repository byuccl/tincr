## @file cells.tcl
#  @brief Query and modify <CODE>cell</CODE> objects in Vivado.
#
#  The <CODE>cells</CODE> ensemble provides procs that query or modify a design's cells.

package provide tincr.cad.design 0.0

package require Tcl 8.5
package require struct 2.1

package require tincr.cad.util 0.0

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export cells
}

## @brief The <CODE>cells</CODE> ensemble encapsulates the <CODE>cell</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::cells {
    namespace export \
        test \
        test_proc \
        new \
        delete \
        rename \
        get \
        get_name \
        get_type \
        get_primitives \
        get_input_pins \
        get_output_pins \
        is_placed \
        is_placement_legal \
        is_lut \
        compatible_with \
        place \
        unplace \
        duplicate \
        insert \
        tie_unused_pins \
        get_lut_eqn \
        set_lut_eqn \
        get_default_value \
        reset_configuration \
        get_configurable_properties
    namespace ensemble create
}

## Executes all unit tests for every proc in the <CODE>cells</CODE> ensemble.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::cells::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad design cells all.tcl] {*}$args
}

## Executes all unit tests for a particular proc in the <CODE>cells</CODE> ensemble.
# @param proc The proc to run the unit tests for.
# @param args The configuration arguments that will be passed to the <CODE>tcltest</CODE> unit testing suite.
proc ::tincr::cells::test_proc {proc args} {
    exec [file join $::env(TINCR_PATH) interpreter windows vivado_tclsh.bat] [file join $::env(TINCR_PATH) tincr_test cad design cells "$proc.test"] {*}$args
}

## Create a new cell.
# @param name The name of the new cell.
# @param lib_cell The name of the library cell this new cell will reference. If this parameter is not provided, or if it is left blank, a black-box cell will be created.
# @return The newly created cell.
proc ::tincr::cells::new { name { lib_cell "" } } {
    if {$lib_cell == ""} {
        set lib_cell "black_box"
    }
    if {[get_lib_cells -quiet $lib_cell] == ""} {
        return [create_cell -reference $lib_cell -black_box $name]
    }
    return [create_cell -reference $lib_cell $name]
}

## Delete a cell.
# @param The cell to delete.
proc ::tincr::cells::delete { cell } {
    remove_cell -quiet $cell
}

## Rename a cell.
# @param The cell to rename.
# @param The new name.
proc ::tincr::cells::rename { cell name } {
    rename_cell -to $name $cell
}

## Queries Vivado's object database for a list of <CODE>cell</CODE> objects that fit the given criteria. This is mostly a wrapper function for Vivado's <CODE>get_cells</CODE> command, though it does add additional features (such as getting the cells of a cell).
proc ::tincr::cells::get { args } {
    set hierarchical 0
    set regexp 0
    set nocase 0
    set quiet 0
    set verbose 0
    tincr::parse_args {hsc filter of_objects match_style} {hierarchical regexp nocase quiet verbose} {patterns} {} $args
    
    set arguments [list]
    
    if {[info exists filter]} {
        lappend arguments "-filter" $filter
    }
    if {[info exists hsc]} {
        lappend arguments "-hsc" $hsc
    }
    if {[info exists match_style]} {
        lappend arguments "-match_style" $match_style
    }
    if {$hierarchical} {
        lappend arguments "-hierarchical"
    }
    if {$regexp} {
        lappend arguments "-regexp"
    }
    if {$nocase} {
        lappend arguments "-nocase"
    }
    if {$quiet} {
        lappend arguments "-quiet"
    }
    if {$verbose} {
        lappend arguments "-verbose"
    }
    if {[info exists patterns]} {
        lappend arguments $patterns
    }
    
    if {[info exists of_objects]} {
        if {[get_property CLASS $of_objects] == "cell"} {
            lappend arguments "-hierarchical"
            return [struct::set intersect [get_cells {*}$arguments] [get_cells "[get_property NAME $of_objects][get_hierarchy_separator]*"]]
        }
        
        lappend arguments "-of_objects" $of_objects
    }
    
    return [get_cells {*}$arguments]
}

## Get the name of a cell.
# @param cell The<CODE>cell</CODE> object.
# @return The name of the cell.
proc ::tincr::cells::get_name { cell } {
    return [get_property NAME $cell]
}

## Get the cell's type. In this case, a cell's type is the library cell it references.
# @param cell The <CODE>cell</CODE> object.
# @return The <CODE>lib_cell</CODE> object that this cell references, or an empty list if there is none.
proc ::tincr::cells::get_type { cell } {
#    set object 0
#    ::tincr::parse_args {} {object} {} {cell} $args
#    
#    if {$object} {
#        return [get_lib_cells -of_objects $cell]
#    } else {
#        return [get_property REF_NAME $cell]
#    }
    return [get_lib_cells -of_objects $cell [get_property REF_NAME $cell]]
}

## Get all primitive (leaf) cells in the design. A primitive cell maps directly to a BEL on the FPGA.
# @return A list of all primitive (leaf) <CODE>cell</CODE> objects in the current design.
proc ::tincr::cells::get_primitives {} {
    return [get_cells -hierarchical -filter {PRIMITIVE_LEVEL==LEAF || PRIMITIVE_LEVEL==INTERNAL}]
}

## Get a cell's input pins.
# @param cell The <CODE>cell</CODE> object.
# @return The input pins of <CODE>cell</CODE>.
proc ::tincr::cells::get_input_pins { cell } {
    return [get_pins -quiet -of_objects $cell -filter {DIRECTION==IN}]
}

## Get a cell's output pins.
# @param cell The <CODE>cell</CODE> object.
# @return The output pins of <CODE>cell</CODE>.
proc ::tincr::cells::get_output_pins { cell } {
    return [get_pins -quiet -of_objects $cell -filter {DIRECTION==OUT}]
}

## Is this cell placed?
# @param cell The <CODE>cell</CODE> object.
# @return TRUE (1) if cell is placed, FALSE (0) otherwise.
proc ::tincr::cells::is_placed { cell } {
#    ::tincr::parse_args {} {} {} {cell} $args
    
    if {[get_property STATUS $cell] == "PLACED" || [get_property STATUS $cell] == "FIXED" || [get_property STATUS $cell] == "ASSIGNED"} {
        return 1
    }
    
    return 0
}

## Is the proposed placement legal? Currently, this function actually places the cell on the given BEL using Vivado's <CODE>place_cell</CODE> command. If no errors are thrown 
#   after placement, then the name of the BEL that the cell is actually placed on is compared with the expected BEL placement. If the names are identical the placement is considered valid.
#   Otherwise, the placement is considered invalid. <code>cell</code> should not be already placed onto a BEL when calling this function. 
# @param cell The cell to be placed.
# @param bel The location the cell is to be placed on.
# @return True (1) if the placement is valid, false (0) otherwise.
proc ::tincr::cells::is_placement_legal { cell bel } {
    
    unplace_cell $cell
    
     set success 0 
     if {[catch {place_cell $cell $bel} fid] == 0} {
         if { [tincr::suffix $bel "/"] == [tincr::suffix [get_property BEL $cell] "."] } {            
             set success 1
         }
     }
     
     unplace_cell $cell
     
     return $success
}

## Is this cell a LUT?
# @param cell The cell to test.
# @return True (1) if <CODE>cell</CODE> is a LUT, false (0) otherwise.
proc ::tincr::cells::is_lut { cell } {
    if {[get_property PRIMITIVE_GROUP $cell] == "LUT"} {
        return 1
    }
    
    return 0
}

## Get the cells in the current design that are compatible for placement on or within the given objects.
# @param objs The object or list of objects. Legal objects include <CODE>bel</CODE>, <CODE>site</CODE>, and <CODE>tile</CODE> objects.
# @return A list of cells in the current design that may be placed on or within the given object(s).
proc ::tincr::cells::compatible_with {objs} {
    set result {}
    set lib_cells [::tincr::lib_cells compatible_with $objs]
    
    foreach lib_cell $lib_cells {
        ::struct::set add result [get_cells -quiet -filter "REF_NAME==[::tincr::get_name $lib_cell]"]
    }
    
    return $result
}

## Place a cell.
# @param cell The <CODE>cell</CODE> object to be placed.
# @param location The location object to place the cell on or in. Legal locations include <CODE>bel</CODE> and <CODE>site</CODE> objects.
proc ::tincr::cells::place { cell location } {
#    ::tincr::parse_args {} {} {location} {cell} $args
    
    if {[get_class $cell] != "cell"} {
        error "ERROR: The value provided for cell is not of the class cell."
    }
    if {[get_class $location] == "bel"} {
        
    } elseif {[get_class $location] == "site"} {
        
    } else {
        error "ERROR: The offered placement location is invalid."
    }
    
    if {[get_property IS_USED $bel]} {
        error "ERROR: The target BEL is already being used."
    }
    
    set_property BEL [::tincr::bels get_info name $bel] $cell
    set_property LOC [::tincr::bels get_info site $bel] $cell
}

## Unplace a cell.
# @param cell The <CODE>cell</CODE> object to be unplaced.
# @return The <CODE>bel</CODE> object that the cell was placed on.
proc ::tincr::cells::unplace { cell } {
    set bel [get_bels -of_objects $cell]
    set_property LOC {} $cell
    set_property BEL {} $cell
    
    return $bel
}

## Duplicate a cell.
# @param ref_cell The cell to copy.
# @param name The name of the new cell.
# @return The newly created duplicate cell object.
proc ::tincr::cells::duplicate { ref_cell name } {
    if {$::tincr::debug} {puts "Program start..."}
    
    set lib_cell [get_lib_cell [get_property REF_NAME $ref_cell]]
    
    set cell [create_cell -reference $lib_cell $name]
    
    set properties [dict create]
    
    foreach property [list_property $ref_cell] {
        dict set properties $property [get_property $property $ref_cell] 
    }
    
    if {$::tincr::debug} {puts "Got properties from ${ref_cell}..."}
    
    dict for {key val} $properties {
        if {[dict get $properties $key] != ""} {
            if {$::tincr::debug} {puts "Set property $key as ${val}..."}
            set_property -quiet $key $val $cell
        }
    }
    
    return $cell
}

## Inserts a cell into the middle of a net. The existing net is disconnected from any sinks on the branch the cell is being inserted into and connected to the input pin on the cell. A new net is created and connected to the output pin on the cell and the sinks of the branch.
# @param cell The cell that will be inserted into the net.
# @param net The net that the cell will be inserted into.
# @param sinks The list of sinks (pins and/or ports) from the net that the new cell will source. This allows the user to identify which branch of the net the cell should be inserted into. If this parameter is omitted or empty, this value defaults to all of the net's sinks.
# @param inpin The input pin on the cell that will be driven by the uphill net. By default, this is the first unused input pin on the cell.
# @param outpin The output pin on the cell that will drive the downhill net. By default, this is the first unused output pin on the cell.
# @param downhill_net_name Specifies a new name for the net downhill of the inserted cell.
proc ::tincr::cells::insert { cell net {sinks ""} {inpin ""} {outpin ""} {downhill_net_name ""} } {
#    set cell ""
#    set sinks ""
#    set inpin ""
#    set outpin ""
#    set downhill_net_name ""
#    ::tincr::parse_args {sinks inpin outpin downhill_net_name} {} {cell} {net} $args
    set net_name [::tincr::get_name $net]
    set cell [get_cells $cell]
    if {$cell == ""} {
        set cell [create_cell -reference [get_library_cells BUF] "${net_name}_BUF"]
    }
    if {$sinks == ""} {
        set sinks [get_pins -quiet -of_objects $net -filter {DIRECTION==IN}]
    }
    if {$inpin == ""} {
        set inpin [lindex [get_pins -quiet -of_objects $cell -filter {DIRECTION==IN && !IS_CONNECTED}] 0]
        if {$inpin == ""} {
            error "ERROR Could not find an available input pin on cell $cell."
        }
    }
    if {$outpin == ""} {
        set outpin [lindex [get_pins -quiet -of_objects $cell -filter {DIRECTION==OUT && !IS_CONNECTED}] 0]
        if {$outpin == ""} {
            error "ERROR Could not find an available output pin on cell $cell."
        }
    }
    if {$downhill_net_name == ""} {
        set max -1
        foreach n [get_nets -hierarchical -quiet -filter "NAME=~_insert_cell_*"] {
            if {[regexp {^.+_([0-9]+)$} [::tincr::get_name $n] matched num]} {
                if {$num > $max} {
                    set max $num
                }
            }
        }
        incr max
        set downhill_net_name "_insert_cell_${max}"
    }
        
    set original_sinks [struct::set union [get_pins -quiet -of_objects $net -filter {DIRECTION!=OUT}] [get_ports -quiet -of_objects $net -filter {DIRECTION!=IN}]]
    
    set invalid_sinks [struct::set difference $sinks $original_sinks]
    if {$invalid_sinks != ""} {
        error "ERROR: Cannot insert cell \"$cell\": \{$invalid_sinks\} is/are not valid sink(s) for net $net."
    }
    
    disconnect_net -net $net -objects $sinks
    
    set downhill_net [create_net $downhill_net_name]
    
    connect_net -hier -net $net -objects $inpin
    connect_net -hier -net $downhill_net -objects $outpin
    connect_net -hier -net $downhill_net -objects $sinks
}

## Tie up or down the unconnected pins of cells in the open synthesized or implemented design. The command uses an internal process to identify whether a pin should be tied up or down.
# @param cell The <CODE>cell</CODE> object whose pins should be tied.
proc ::tincr::cells::tie_unused_pins { cell } {
    tie_unused_pins -of_objects $cell
}

## Get the LUT's equation in sum-of-products form.
# @param cell The cells whose equation you wish to retrieve.
# @return The LUT's equation in sum-of-products form.
proc ::tincr::cells::get_lut_eqn { cell } {
    if {![is_lut $cell]} {
        return
    }
    
    set num_inputs [llength [get_input_pins $cell]]
    set num_combinations [expr 1 << $num_inputs]
    
    # Parse the hex value into an integer so that we can work with it
    scan [get_property INIT $cell] "$num_combinations'h%x" init
    
    set terms [list]
    for {set cnt 0} {$cnt < $num_combinations} {incr cnt} {
        if {[expr $init & (1 << $cnt)]} {
            set inner_terms [list]
            for {set i 0} {$i < $num_inputs} {incr i} {
                set sign ""
                if {![expr ($cnt >> $i) & 1]} {
                    set sign "~"
                }
                
                lappend inner_terms "${sign}I$i"
            }
            
            lappend terms "([join $inner_terms "&"])"
        }
    }
    
    if {![llength $terms]} {
        return "O=0"
    }
    
    # Format the output
    return "O=[join $terms "|"]"
}

## Set the LUT's equation.
# @param cell The cell whose equation you wish to set.
# @param equation The equation to set. Use I0, I1, etc. as inputs and O as the output. i.e. O=I0&~I1|(I1*I2).
proc ::tincr::cells::set_lut_eqn { cell equation } {
    if {![is_lut $cell]} {
        return
    }
    
    set num_inputs [llength [get_input_pins $cell]]
    set num_combinations [expr 1 << $num_inputs]
    
    # Legal Operator Set:
    #   XOR: @ ^
    #   AND: * & .
    #   OR:  + |
    #   NOT: ~ !
    set formatted_equation [string map {@ ^ * & . & + | ! ~ I $I O "" = ""} $equation]
    
    set result 0
    for {set cnt 0} {$cnt < $num_combinations} {incr cnt} {
        # Set the inputs
        for {set i 0} {$i < $num_inputs} {incr i} {
            set "I$i" [expr ($cnt >> $i) & 1]
        }
        
        # If this equation equates as true, prepend a '1' to the beginning of $result
        if {[expr $formatted_equation]} {
            incr result [expr 1 << $cnt]
        }
    }
    
    # Format $result as a hexadecimal number that Vivado will accept.
    set_property INIT "$num_combinations'h[format %[expr $num_combinations >> 2]X $result]" $cell
}

## Gets the default value of a configuration for a given cell. For example, calling
#   <code> tincr::cells::get_default_value $cell IS_C_INVERTED </code> on a Flip Flop cell will 
#   return the <code>CONFIG.IS_C_INVERTED.DEFAULT</code> property of the backing library cell. 
#
# @param cell Cell instance
# @param config Configuration to get the default value of
# @return The default value of the specified config
proc ::tincr::get_default_value {cell config} {
    return [get_property "CONFIG.$config.DEFAULT" [get_lib_cells -of $cell]]
}

## Resets the specified configuration of the cell to their default. 
#
# @param cell Cell instance 
# @param config_list List of configurations to reset 
proc ::tincr::reset_configuration {cell config_list} {
    
    foreach config $config_list {
        set default [get_property "CONFIG.$config.DEFAULT" [get_lib_cells -of $cell]]
        set_property $config $default $cell  
    }
}

## Creates and returns a list of properties on the specified cell object that are configurable.
#   TODO: cache this information
#
# @param cell Vivado cell instance
# @return A set of reconfigurable properties on that cell  
#
proc tincr::cells::get_configurable_properties {cell} {

    set config_properties [list]
    
    foreach property [list_property [get_lib_cell -of $cell]] {
        if { [regexp {CONFIG\.([^\.]+)\.DEFAULT$} $property -> match] } {
            lappend config_properties $match
        }
    }
    
    return $config_properties
}
