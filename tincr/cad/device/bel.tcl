## @file bel.tcl
#  @brief Query <CODE>bel</CODE> objects in Vivado.
#
#  The <CODE>bel</CODE> ensemble acts as a wrapper class for Vivado's native bel type.

package provide tincr.cad.device 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export bel
}

## @brief The <CODE>bels</CODE> ensemble encapsulates the <CODE>bel</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::bel {
    namespace export \
        get_name \
        get_type \
        get_cell \
        get_cells \
        get_tile \
        get_site \
        get_bel_pins \
        is_lut5 \
        is_lut6 \
        is_lut \
        get_compatible_lib_cells
    namespace ensemble create
}

# Static methods

# Member methods

## Get the name of a BEL.
# @param this The <CODE>bel</CODE> object.
# @return The name of the BEL as a string.
proc ::tincr::bel::get_name { this } {
    return [get_property NAME $this]
}

## Get the type of a BEL.
# @param bel The <CODE>bel</CODE> object.
# @return The BEL's type as a string.
proc ::tincr::bel::get_type { this } {
    return [get_property TYPE $this]
}

proc ::tincr::bel::get_cell { this } {
    return [::get_cells -of_objects $this]
}

## Get the cell(s) placed on this BEL. Can be more than one if there is hierarchy.
proc ::tincr::bel::get_cells { this } {
    return [::get_cells -hierarchical -of_objects $this]
}

proc ::tincr::bel::get_tile { this } {
    return [::get_tiles -of_objects $this]
}

proc ::tincr::bel::get_site { this } {
    return [::get_sites -of_objects $this]
}

proc ::tincr::bel::get_bel_pins { this } {
    return [::get_bel_pins -of_objects $this]
}

## Is this BEL a LUT5
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT5, false (0) otherwise.
proc ::tincr::bel::is_lut5 { this } {
    set type [get_type $this]
    if {$type=="LUT5" || $type=="LUT_OR_MEM5"} {
        return 1
    }
    return 0
}

## A simple proc to tell if a given BEL is a LUT6
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT6, false (0) otherwise.
proc ::tincr::bel::is_lut6 { this } {
    set type [get_type $this]
    if {$type=="LUT6" || $type=="LUT_OR_MEM6"} {
        return 1
    }
    return 0
}

## A simple proc to tell if a given BEL is a LUT
# @param bel The <CODE>bel</CODE> object.
# @return True (1) if the BEL is a LUT, false (0) otherwise.
proc ::tincr::bel::is_lut { this } {
    set type [get_type $this]
    if {$type=="LUT6" || $type=="LUT5" || $type=="LUT_OR_MEM6" || $type=="LUT_OR_MEM5"} {
        return 1
    }
    return 0
}

proc ::tincr::bel::get_compatible_lib_cells { this } {
    ::tincr::cache::get array.bel_type.lib_cells bel_type2lib_cells
    return $bel_type2lib_cells([get_type $this])
}
