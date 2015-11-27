package provide tincr.cad.device 0.0

package require Tcl 8.5
package require snit 2.2
package require struct 2.1

snit::type bel {
    option -name -default {} -readonly yes -cgetmethod GetName
    option -type -default {} -readonly yes -cgetmethod GetType
    
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
    
    constructor {name} {
        variable _obj
        set _obj [$type getBel $name]
        if {$_obj == {}} {
            error "$name is not a BEL in the current device."
        }
    }
    
    method GetName {} {
        variable _obj
        if {$options(-name) == {}} {
            set options(-name) [get_property NAME $_obj]
        }
        return $options(-name)
    }
    
    method GetType {} {
        variable _obj
        if {$options(-type) == {}} {
            set options(-type) [get_property TYPE $_obj]
        }
        return $options(-type)
    }
    
    method GetSite {} {
        error "Not implemented."
    }
    
    method IsLut {} {
        variable _obj
        set type [$self getType]
        if {$type=="LUT6" || $type=="LUT5" || $type=="LUT_OR_MEM6" || $type=="LUT_OR_MEM5"} {
            return 1
        }
        return 0
    }
    
    method IsLut5 {} {
        variable _obj
        set type [$self getType]
        if {$type=="LUT5" || $type=="LUT_OR_MEM5"} {
            return 1
        }
        return 0
    }
    
    method IsLut6 {} {
        variable _obj
        set type [$self getType]
        if {$type=="LUT6" || $type=="LUT_OR_MEM6"} {
            return 1
        }
        return 0
    }
}