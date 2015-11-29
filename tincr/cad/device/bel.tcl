package provide tincr.cad.device 0.0

package require Tcl 8.5
package require stooop 4.4
namespace import stooop::*

class bel {}
proc bel::bel {this obj} {
    # set a few members of the class namespace empty named array
    set ($this,obj) [get_bels $obj]
}

proc bel::GetType {this} {
    return [get_property TYPE $($this,obj)]
}

proc bel::IsLut {this} {
    set type [GetType $this]
    if {$type=="LUT6" || $type=="LUT5" || $type=="LUT_OR_MEM6" || $type=="LUT_OR_MEM5"} {
        return 1
    }
    return 0
}
