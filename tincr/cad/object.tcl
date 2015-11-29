package provide tincr.cad 0.0

package require Tcl 8.5
package require snit 2.2
package require struct 2.1

snit::type object {
    option -obj -default {} -readonly yes -configuremethod SetObj
    option -name -default {} -readonly yes -cgetmethod GetName
    option -class -default {object} -readonly yes -cgetmethod GetClass
    
    constructor {obj} {
        $self configure -obj $obj
    }
    
    method SetObj {option value} {
        set options(-obj) $value
    }
    
    method GetProperty {property} {
        return [get_property $property [$self cget -obj]]
    }
    
    method GetName {{option {}}} {
        if {$options(-name) == {}} {
            set options(-name) [$self GetProperty NAME]
        }
        return $options(-name)
    }
    
    method GetClass {{option {}}} {
        if {$options(-class) == {}} {
            set options(-class) [$self GetProperty CLASS]
        }
        return $options(-class)
    }
}