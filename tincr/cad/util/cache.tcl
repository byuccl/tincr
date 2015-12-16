# cache.tcl 
# Comprises the entire caching framework for Tincr.
#
# The cache package contains procs for defining, accessing, generating, saving, and loading caches for use in Tincr.

# Register the package
package provide tincr.cad.util 0.0

package require Tcl 8.5
package require struct 2.1

namespace eval ::tincr::cache {
    namespace export \
        define \
        path \
        namespace_path \
        directory_path \
        initialize \
        get \
        free \
        refresh
}

set ::tincr::cache::path_scripts [dict create]
set ::tincr::cache::generate_scripts [dict create]
set ::tincr::cache::save_scripts [dict create]
set ::tincr::cache::load_scripts [dict create]

## Register a cache with Tincr's caching database. You must provide a name for the cache(s), a script for computing the path of the cache (as a list), a script for generating the cache, and a script for saving/loading the cache to/from disk.
# @param path_script A script for computing the path of the cache(s) as a list. This is used to determine the namespace where the cache will be stored and the path it will be saved to on disk. If nothing, no new script script is registered.
# @param generate_script A script for generating the cache(s). If nothing, no new script script is registered.
# @param save_script A script for saving the cache(s). If nothing, no new script script is registered.
# @param load_script A script for loading the cache(s). If nothing, no new script script is registered.
proc ::tincr::cache::define {names path_script generate_script save_script load_script} {
    foreach name $names {
        if {$path_script != ""} {
            dict set ::tincr::cache::path_scripts $name $path_script
        }
        if {$generate_script != ""} {
            dict set ::tincr::cache::generate_scripts $name $generate_script
        }
        if {$save_script != ""} {
            dict set ::tincr::cache::save_scripts $name $save_script
        }
        if {$load_script != ""} {
            dict set ::tincr::cache::load_scripts $name $load_script
        }
    }
}

proc ::tincr::cache::path {cache} {
    if {[dict exists $::tincr::cache::path_scripts $cache]} {
        eval [dict get $::tincr::cache::path_scripts $cache]
    }
}

proc ::tincr::cache::namespace_path {cache} {
    return "::[join [list tincr cache {*}[path $cache]] ::]"
}

proc ::tincr::cache::directory_path {cache} {
    return [file join $::env(TINCR_PATH) cache {*}[path $cache]]
}

proc ::tincr::cache::generate {cache} {
    if {[dict exists $::tincr::cache::generate_scripts $cache]} {
        eval [dict get $::tincr::cache::generate_scripts $cache]
    } else {
        return 0
    }
    return 1
}

proc ::tincr::cache::save {cache} {
    if {[dict exists $::tincr::cache::save_scripts $cache]} {
        eval [dict get $::tincr::cache::save_scripts $cache]
    } else {
        return 0
    }
    return 1
}

proc ::tincr::cache::load {cache} {
    if {[dict exists $::tincr::cache::load_scripts $cache]} {
        eval [dict get $::tincr::cache::load_scripts $cache]
    } else {
        return 0
    }
    return 1
}

proc ::tincr::cache::initialize {cache} {
    if {![load $cache]} {
        puts "Generating the data for cache $cache..."
        if {[generate $cache]} {
            puts "Cache $cache generated successfully."
            save $cache
        } else {
            error "Could not initialize cache: $cache"
        }
    }
}

# TODO The naming scheme for these caches is terrible...
#      Is it even a good idea to standardize how they are named?

## Get a cache and assign it to destination
# @param cache The cache to get. The cache will be generated if it doesn't exist. Defaults to destination.
# @param destination The name of the variable that the cache will be assigned to.
# @return Nothing. This is because arrays cannot be passed between procs.
proc ::tincr::cache::get { cache {destination ""} } {
    if {$destination == ""} {
        set destination $cache
    }
    
    if {![info exists "[::tincr::cache::namespace_path $cache]::$cache"]} {
        initialize $cache
    }
    
    uplevel "upvar #0 [::tincr::cache::namespace_path $cache]::$cache $destination"
}


proc ::tincr::cache::free {cache} {
    set var "[::tincr::cache::namespace_path $cache]::$cache"
    
    if {[info exists $var]} {
        unset $var
    }
}

proc ::tincr::cache::refresh {cache} {
    free $cache
    initialize $cache
}

######################## Begin cache definitions #########################

# This is a template for a cache definition
::tincr::cache::define {
    # Cache name(s)
} {
    # Path script
} {
    # Generate script
} {
    # Save script
} {
    # Load script
}

::tincr::cache::define {
    array.bel_pin.bel
    array.bel_type.bels
    array.bel.site_types
    array.site.site_type.bels
} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        ::tincr::run_in_temporary_project {
            foreach site [get_sites -quiet] {
                set site_types [get_property SITE_TYPE $site]
                lappend site_types {*}[get_property ALTERNATE_SITE_TYPES $site]
                
                foreach site_type $site_types {
                    set_property MANUAL_ROUTING $site_type $site
                    foreach bel [get_bels -quiet -of_objects $site] {
                        lappend array.bel_type.bels([get_property TYPE $bel]) $bel
                        lappend array.bel.site_types([get_property NAME $bel]) $site_type
                        lappend array.site.site_type.bels($site,$site_type) $bel
                        
                        foreach bel_pin [get_bel_pins -quiet -of_objects $bel] {
                            lappend array.bel_pin.bel($bel_pin) $bel
                        }
                    }
                    reset_property MANUAL_ROUTING $site
                }
            }
        }
    }
} {} {}

::tincr::cache::define {
    array.bel_pin.bel
    array.bel_type.bels
    array.site.site_type.bels
} {} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.site.site_type.bels]
        file mkdir $dir
        set out [open [file join $dir "array.site.site_type.bels.cache"] w]
        puts $out [array get array.site.site_type.bels]
        close $out
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.site.site_type.bels]
        set file [file join $dir "array.site.site_type.bels.cache"]
        if {[file exists $file]} {
            ::tincr::run_in_temporary_project {
                set in [open $file r]
                array set temp [read $in]
                close $in
            
                foreach key [array names temp] {
                    set tokens [split $key ,]
                    set site [get_sites [lindex $tokens 0]]
                    set site_type [lindex $tokens 1]
            
                    set_property MANUAL_ROUTING $site_type $site
                    foreach bel [get_bels -of_objects $site $temp($key)] {
                        lappend array.bel_type.bels([get_property TYPE $bel]) $bel
                        lappend array.bel.site_types([get_property NAME $bel]) $site_type
                        lappend array.site.site_type.bels($site,$site_type) $bel
                        
                        foreach bel_pin [get_bel_pins -quiet -of_objects $bel] {
                            lappend array.bel_pin.bel($bel_pin) $bel
                        }
                    }
                    reset_property MANUAL_ROUTING $site
                }
                
                unset temp
            }
        } else {
            return 0
        }
    }
}

::tincr::cache::define {
    array.bel.site_types
} {} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.bel.site_types]
        file mkdir $dir
        set out [open [file join $dir "array.bel.site_types.cache"] w]
        puts $out [array get array.bel.site_types]
        close $out
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.bel.site_types]
        set file [file join $dir "array.bel.site_types.cache"]
        if {[file exists $file]} {
            set in [open $file r]
            array set array.bel.site_types [read $in]
            close $in
        } else {
            return 0
        }
    }
}

::tincr::cache::define {
    array.bel_type.lib_cells
    array.lib_cell.bel_types
} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        ::tincr::run_in_temporary_project {
            # If the input pins on all the cells are connected to a part, this will prevent Vivado from crashing when placing IO cells
            set port [create_port -direction IN port]
            set net [create_net net]
            connect_net -net net -objects port
            
            set architecture [get_property ARCHITECTURE [get_parts -of_objects [current_design]]]
            set lib_cells [lsort [::tincr::lib_cells get -architecture $architecture -of_object [get_libs UNISIM]]]
            set cells [list]
            foreach lib_cell $lib_cells {
                if {$::tincr::debug} {puts "DEBUG: Creating a cell for $lib_cell..."}
                set cell [create_cell -quiet -reference $lib_cell [::tincr::get_name $lib_cell]]
                if {[get_lib_cells -quiet -of_objects $cell] == ""} {
                    puts "WARNING: Couldn't create cell for $lib_cell."
                    continue
                }
                
                foreach pin [get_pins -quiet -of_objects $cell -filter {DIRECTION==IN}] {
                    connect_net -quiet -net net -objects $pin
                }
                
                lappend cells $cell
            }
            
            foreach bel [::tincr::bels unique] {
                set site [get_sites -of_objects $bel]
                if {[get_property ALTERNATE_SITE_TYPES $site] != ""} {
                    ::tincr::sites set_type $site [lindex [::tincr::bels get_site_types $bel] 0]
                }
                
                foreach cell $cells {
                    set lib_cell [get_lib_cells [::tincr::get_name $cell]]
                    
                    if {$::tincr::debug} {puts -nonewline "DEBUG: Testing compatibility between cell type $cell and BEL $bel..."}
                    if {![catch {place_cell [::tincr::get_name $cell] [::tincr::get_name $bel]}]} {
                        set bel_type [get_property TYPE $bel]
                        
                        if {[get_bels -quiet -of_objects $cell] == $bel} {
                            if {$::tincr::debug} {puts "YES"}
                            lappend array.bel_type.lib_cells($bel_type) $lib_cell
                            lappend array.lib_cell.bel_types($lib_cell) $bel_type
                        } else {
                            if {$::tincr::debug} {puts "NO"}
                            puts "WARNING: Cell type $lib_cell was not placed on $bel, but [get_bels -quiet -of_objects $cell] instead."
                        }
                        
                        unplace_cell [::tincr::get_name $cell]
                    } elseif {$::tincr::debug} {puts "NO"}
                }
                if {[get_property ALTERNATE_SITE_TYPES $site] != ""} {
                    # Reset the site's type
                    ::tincr::sites set_type [get_sites -of_objects $bel]
                }
            }
        }
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.lib_cell.bel_types]
        file mkdir $dir
        set out [open [file join $dir "array.lib_cell.bel_types.cache"] w]
        puts $out [array get array.lib_cell.bel_types]
        close $out
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.lib_cell.bel_types]
        set file [file join $dir "array.lib_cell.bel_types.cache"]
        if {[file exists $file]} {
            set in [open $file r]
            array set array.lib_cell.bel_types [read $in]
            close $in
            
            foreach key [array names array.lib_cell.bel_types] {
                set lib_cell [get_lib_cells $key]
                
                foreach bel_type [lindex [array get {array.lib_cell.bel_types} $key] 1] {
                    lappend array.bel_type.lib_cells($bel_type) $lib_cell
                }
            }
        } else {
            return 0
        }
    }
}

::tincr::cache::define {
    array.site.site_types
    array.site_type.sites
    list.site.site_type
} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        tincr::run_in_temporary_project {
            set sites [get_sites]
            foreach site $sites {
                set types [get_property SITE_TYPE $site]
                lappend types {*}[get_property ALTERNATE_SITE_TYPES $site]
                foreach type $types {
                    lappend array.site.site_types($site) $type
                    lappend array.site_type.sites($type) $site
                    lappend list.site.site_type $site $type
                }
            }
        }
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.site.site_types]
        file mkdir $dir
        set out [open [file join $dir "array.site.site_types.cache"] w]
        puts $out [array get array.site.site_types]
        close $out
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [file join [::tincr::cache::directory_path array.site.site_types] "array.site.site_types.cache"]
        if {[file exists $dir]} {
            set in [open $dir r]
            array set temp [read $in]
            close $in
            
            foreach key [array names temp] {
                set site [get_sites $key]
                
                foreach type $temp($key) {
                    lappend array.site.site_types($site) $type
                    lappend array.site_type.sites($type) $site
                    lappend list.site.site_type $site $type
                }
            }
            
            unset temp
        } else {
            return 0
        }
    }
}

::tincr::cache::define {
    array.bel_pin.bel
    array.bel_type.bels
    array.bel.site_types
    array.site.site_type.bels
    array.bel_type.lib_cells
    array.lib_cell.bel_types
    array.lib_cell.bels
    array.site.site_types
    array.site_type.sites
    list.site.site_type
} {
    set part [get_part -of_objects [current_design]]
    set family [get_property FAMILY $part]
    set architecture [get_property ARCHITECTURE $part]
    set device [get_property DEVICE $part]
    set package [get_property PACKAGE $part]
    
    # TODO I don't know for sure what the correct "resolutions" are for these
    #      caches; so I just assigned them all to the most fine-grained
    #      path, based on part. This means these caches will be re-
    #      generated/populated when the user switches parts in Vivado.
    #      Performance gains may be observed for users that operate across
    #      multiple parts if a less-detailed path can be and is used for
    #      each of these caches (i.e. family instead of part) 
    set path [list $family $architecture $device $package]
    
    return $path
} {} {} {}

# The array.part.site_types cache provides quick access to the list of site types on a given part.
::tincr::cache::define {
    array.part.site_types
} {
    return "all"
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set parts [get_parts]
        set i 0
        foreach part $parts {
            puts -nonewline "\rPercent complete: [expr ($i * 100) / [llength $parts]]%"
            tincr::run_in_temporary_project -part $part {
                set site_types [tincr::sites get_types]
                foreach site_type $site_types {
                    lappend array.part.site_types($part) $site_type
                }
            }
            incr i
        }
        puts "\rPercent complete: 100%"
        
        return 1
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [::tincr::cache::directory_path array.part.site_types]
        file mkdir $dir
        set out [open [file join $dir "array.part.site_types.cache"] w]
        puts $out [array get array.part.site_types]
        close $out
    }
} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dir [file join [::tincr::cache::directory_path array.part.site_types] "array.part.site_types.cache"]
        if {[file exists $dir]} {
            set in [open $dir r]
            array set array.part.site_types [read $in]
            close $in
            
            # Since the list of parts isn't static across multiple versions of Vivado, fail when there is a discrepancy.
            if {[llength [struct::set difference [get_parts] [array names array.part.site_types]]] != 0} {
                return 0
            }
        } else {
            return 0
        }
        
        return 1
    }
}

::tincr::cache::define {
    # Cache name(s)
    dict.site_type.src_bel.src_pin.snk_bel.snk_pins
} {
    # Path script
    set part [get_part -of_objects [current_design]]
    set family [get_property FAMILY $part]
    return [list $family "primitive_defs"]
} {
    # Generate script
    
} {
    # Save script
} {
    # Load script
    namespace eval [::tincr::cache::namespace_path $cache] {
        set dict.site_type.src_bel.src_pin.snk_bel.snk_pins [dict create]
        foreach site_type [tincr::sites get_types] {
            set filepath [file join [::tincr::cache::directory_path dict.site_type.src_bel.src_pin.snk_bel.snk_pins] "$site_type.def"]
            
            if {[file exists $filepath]} {
                    set dict.site_type.src_bel.src_pin.snk_bel.snk_pins [dict merge ${dict.site_type.src_bel.src_pin.snk_bel.snk_pins} [::tincr::primitive_def::parse $filepath]]
            } else {
                puts "ERROR One or more primitive definitions are missing."
                return 0
            }
        }

        return 1
    }
}

::tincr::cache::define {
    array.lib_cell.bels
} {} {
    namespace eval [::tincr::cache::namespace_path $cache] {
        ::tincr::cache::get array.lib_cell.bel_types libcell2beltypes
        ::tincr::cache::get array.bel_type.bels beltype2bels
        
        array set array.lib_cell.bels {}
        foreach lib_cell [array names libcell2beltypes] {
            set bels {}
            foreach bel_type $libcell2beltypes($lib_cell) {
                struct::set add bels $beltype2bels($bel_type)
            }
            set array.lib_cell.bels($lib_cell) $bels
        }
    }
} {} {}
