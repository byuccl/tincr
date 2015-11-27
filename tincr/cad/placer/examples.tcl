package provide tincr.cad.placer 0.0

package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

package require Tcl 8.5

# Summary:
# A simple random placer to demonstrate how to write a placer using Tincr

# Argument Usage:
# [verbose = 0] : Flag to print verbose information
# [seed] : If declared, provides the seed to the placer's RNG

# Return Value:
# None.

# Categories: xilinxtclstore, byu, tincr, design

# Notes:
# This 
proc ::tincr::random_placer { {seed ""} {verbose 0} } {
    # Let Vivado place all of the ports in the design
    place_ports -quiet
    
    # Seed the RNG if a seed was provided
    if {$seed != ""} {
        expr srand($seed)
    }
        
    set cells [::tincr::cells get_primitives]
    
    foreach cell $cells {
        if {$verbose} {
            puts "<[clock format [clock seconds] -format %H:%M:%S]> Placing cell $cell..."
        }
        
        # Skip cells that have already been placed, i.e. IO
        if {[::tincr::cells is_placed $cell]} continue
        
        set cell_type [get_lib_cells -of_objects $cell]
        if {$cell_type == ""} {
            puts "WARNING: No library cell was found for [get_property NAME $cell]."
            continue
        }
        
        # Skip IO cells (the user can let Xilinx's placer handle this stuff)
        if {[get_property NAME $cell_type] == "BUFG" || [get_property NAME $cell_type] == "IBUF" || [get_property NAME $cell_type] == "OBUF"} {
            puts "INFO: Skipping cell $cell because it is of type $cell_type."
            continue
        }
        
        # Skip GND/VCC cells - Vivado must place these
        if {[::tincr::get_name $cell_type] == "VCC" || [::tincr::get_name $cell_type] == "GND"} {
            puts "INFO: Skipping cell $cell because it is of type $cell_type."
            continue
        }

        # Get the list of compatible BELs for this cell type
        set bels [::tincr::bels compatible_with_cell $cell]
        
        set idx [expr int(rand() * [llength $bels])]
        set watch_dog 0
        
        # Find a free bel
        set bel [lindex $bels $idx]
        
        if {$verbose} {
            puts "\tCandidate BEL: $bel"
        }
#        while {[placement place_cell $cell $bel] != 0} {}
        while {[catch {place_cell [::tincr::get_name $cell] [::tincr::get_name $bel]} fid] || [::tincr::get_type $bel] == "RAMBFIFO36E1_RAMBFIFO36E1"} {
            incr watch_dog
            if {$watch_dog >= [llength $bels]} {
                error "Placement failed."
            }
            
            incr idx
            if {$idx >= [llength $bels]} {
                set idx 0
            }
            
            set bel [lindex $bels $idx]
            if {$verbose} {
                puts "\tCandidate BEL: $bel"
            }
        }
    }
}
