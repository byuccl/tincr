package provide tincr.cad.device 0.0

package require Tcl 8.5
package require snit 2.2
package require struct 2.1

snit::type bel {
    # The bel class extends the object class
    component base
    delegate option * to base
    delegate method * to base
    
    # Properties belonging to the BEL object
    option -type -default {} -readonly yes -cgetmethod GetType
    option -site -default {} -readonly yes -cgetmethod GetSite
    
    constructor {name} {
        # This class extends the object class
        install base using object %AUTO% [$type getBel $name]
    }
    
    destructor {
        catch {$base destroy}
    }
    
    method GetType {{option {}}} {
        if {$options(-type) == {}} {
            set options(-type) [$self GetProperty TYPE]
        }
        return $options(-type)
    }
    
    method GetSite {option} {
        if {$options(-site) == {}} {
            set options(-site) [site %AUTO% [get_sites -of [$self cget -obj]]]
        }
        return $options(-site)
    }
    
    method IsLut {} {
        set type [$self GetType]
        if {$type=="LUT6" || $type=="LUT5" || $type=="LUT_OR_MEM6" || $type=="LUT_OR_MEM5"} {
            return 1
        }
        return 0
    }
    
    method IsLut5 {} {
        set type [$self GetType]
        if {$type=="LUT5" || $type=="LUT_OR_MEM5"} {
            return 1
        }
        return 0
    }
    
    method IsLut6 {} {
        set type [$self GetType]
        if {$type=="LUT6" || $type=="LUT_OR_MEM6"} {
            return 1
        }
        return 0
    }
    
    # Static BEL methods
    typemethod getBels {filter} {
        return [get_bels $filter]
    }
    
    typemethod getBel {name} {
        set bel [get_bels $name]
        if {[llength $bel] != 1} {
            set bel {}
        }
        
        return $bel
    }
}