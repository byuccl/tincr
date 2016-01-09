# cache.tcl 
# Comprises the entire caching framework for Tincr.
#
# The cache package contains procs for defining, accessing, generating, saving, and loading caches for use in Tincr.

# Register the package
package provide tincr.cad.cache 0.0

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
