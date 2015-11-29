package provide tincr.cad.device 0.0

package require Tcl 8.5
package require snit 2.2
package require struct 2.1

snit::type site {
    # The bel class extends the object class
    component base
    delegate option * to base
    delegate method * to base
    
    # Properties belonging to the BEL object
    option -type -default {} -readonly yes -cgetmethod GetType
    
    constructor {name} {
        # This class extends the object class
        install base using object %AUTO% [$type getSite $name]
    }
    
    destructor {
        catch {$base destroy}
    }
    
    method GetType {{option {}}} {
        if {$options(-type) == {}} {
            set options(-type) [$self GetProperty SITE_TYPE]
        }
        return $options(-type)
    }
    
    method GetBels {} {
        error "Not implemented."
    }
    
    # Static BEL methods
    typemethod getSites {filter} {
        return [get_sites $filter]
    }
    
    typemethod getSite {name} {
        set site [get_sites $name]
        if {[llength $site] != 1} {
            set site {}
        }
        
        return $site
    }
}