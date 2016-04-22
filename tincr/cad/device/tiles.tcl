## @file tiles.tcl
#  @brief Query <CODE>tile</CODE> objects in Vivado.
#
#  The <CODE>tiles</CODE> ensemble provides procs that query a device's tiles.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export tiles
}

## @brief The <CODE>tiles</CODE> ensemble encapsulates the <CODE>tile</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::tiles {
    namespace export \
        test \
        get \
        num_rows \
        num_cols \
        unique \
        iterate \
        get_types \
        manhattan_distance
    namespace ensemble create
}

proc ::tincr::tiles::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device tiles all.tcl] {*}$args
}

proc ::tincr::tiles::get { args } {
    return [get_tiles {*}$args]
}

## Get the number of rows in a part. For unknown reasons, this number is not stored as a property in the <CODE>device</CODE> object, and can only be obtained by iterating through all tiles and returning the maximum row value.
# @return The number of rows of tiles in the current part.
proc ::tincr::tiles::num_rows {} {
    set rows 0
    
    ::foreach tile [get_tiles] {
        set row [expr [get_property ROW $tile] + 1]
        
        if {$row > $rows} {
            set rows $row
        }
    }
    
    return $rows
}

## Get the number of columns in a part. For unknown reasons, this number is not stored as a property in the <CODE>device</CODE> object, and can only be obtained by iterating through all tiles and returning the maximum column value.
# @return The number of columns of tiles in the current part.
proc ::tincr::tiles::num_cols {} {
    set cols 0
    
    ::foreach tile [get_tiles] {
        set col [expr [get_property COLUMN $tile] + 1]
        
        if {$col > $cols} {
            set cols $col
        }
    }
    
    return $cols
}


## Get a dictionary that contains one <CODE>tile</CODE> object of each tile type.
# @return A Tcl dict that maps each tile type to one <CODE>tile</CODE> object in the current part.
proc ::tincr::tiles::unique {} {
    # Summary:
    # Get a dictionary that contains one tile of each tile type.

    # Argument Usage:

    # Return Value:
    # a Tcl dict that maps each tile type to one tile

    # Categories: xilinxtclstore, byu, tincr, device

    set tiles {}
    
    ::foreach tile [get_tiles] {
        dict set tiles [get_property TYPE $tile] $tile
    }
    
    return $tiles
}

## Iterates over every tile on the part, while executing a given script.
# TODO Fix the arguments.
proc ::tincr::tiles::iterate { args } {
    ::tincr::parse_args {} {} {} {tileVar body} $args
    upvar 1 $tileVar tile
    
    # TODO I don't think this next line will work if the body references a var name other than "tile"
    ::foreach tile [get_tiles] {
        uplevel $body
    }
}

## Get a list of all tile types present in the current device. This returned list will be a subset of the list of all possible site types returned by the Vivado command: list_property_value TILE_TYPE -class tile.
# @return A sorted list of all tile types present in the current device.
proc ::tincr::tiles::get_types {} {
    return [lsort [list_property_value -class tile TILE_TYPE]]
}

## Get the Manhattan distance between two tiles. The Manhattan distance is calculated using the tile coordinates as follows: distance = |tile1_x - tile2_x| + |tile1_y - tile2_y|
# @param tile1 The start tile.
# @param tile2 The end tile.
# @return The Manhattan distance between the two tiles or -1 if the arguments are invalid.
proc ::tincr::tiles::manhattan_distance { tile1 tile2 } {
    if {[regexp {X(\d+)Y(\d+)} $tile1 match t1x t1y] && [regexp {X(\d+)Y(\d+)} $tile2 match t2x t2y]} {
        return [expr {abs($t2x - $t1x) + abs($t2y - $t1y)}]
    } else {
        return -1
    }
}

# TODO implement tiles get_info
