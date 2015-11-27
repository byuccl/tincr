## @file site_pips.tcl
#  @brief Query <CODE>site_pip</CODE> objects in Vivado.
#
#  The <CODE>site_pips</CODE> ensemble provides procs that query a device's site PIPs.

package provide tincr.cad.device 0.0

package require Tcl 8.5

## @brief All of the Tcl procs provided in the design package are members of the <CODE>::tincr</CODE> namespace.
namespace eval ::tincr {
    namespace export site_pips
}

## @brief The <CODE>site_pips</CODE> ensemble encapsulates the <CODE>site_pip</CODE> class from Vivado's Tcl data structure.
namespace eval ::tincr::site_pips {
    namespace export \
        test \
        get \
        get_info \
        is_route_through \
        parse_name \
        get_site \
        get_bel
    namespace ensemble create
}

proc ::tincr::site_pips::test {args} {
    source_with_args [file join $::env(TINCR_PATH) tincr_test cad device site_pips all.tcl] {*}$args
}

proc ::tincr::site_pips::get { args } {
    return [get_site_pips {*}$args]
}

proc ::tincr::site_pips::get_info { site_pip {info site_pip} } {
    # Summary:
    # Get information about a bel_pin that can be found by parsing its name.

    # Argument Usage:
    # bel_pin : the bel_pin object or bel_pin name to query
    # info : which information to get about bel_pin — valid values: site, bel, or name

    # Return Value:
    # the requested information

    # Categories: xilinxtclstore, byu, tincr, device

    if {[regexp {(\w+)/(\w+):(\w+)} $site_pip matched site bel pin]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$site_pip\" isn't a valid BEL pin name."
    }
}

proc ::tincr::site_pips::is_route_through { site_pip } {
    if {[get_bel $site_pip] != ""} {
        return 1
    }
    
    return 0
}

proc ::tincr::site_pips::parse_name { site_pip {info site_pip} } {
    if {[regexp {(\w+)/(\w+):(\w+)} $site_pip matched site element pin]} {
        return [subst $[subst $info]]
    } else {
        error "ERROR: \"$site_pip\" isn't a valid site_pip name."
    }
}

proc ::tincr::site_pips::get_site { site_pip } {
    return [get_sites -quiet [parse_name $site_pip site]]
}

proc ::tincr::site_pips::get_bel { site_pip } {
    return [get_bels -quiet -of_objects [get_site $site_pip] "*[parse_name $site_pip element]"]
}
