package provide tincr.io.device 0.0

package require Tcl 8.5
package require struct 2.1
package require simulation::annealing 0.2

package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        write_xdlrc \
        write_xdlrc_tile \
        write_primitive_defs \
        write_partial_primitive_def \
        test_eappd \
        extract_all_partial_primitive_defs \
        get_parts_unique
}

proc ::tincr::write_xdlrc { args } {
    # Set defaults for incoming agruments
    set brief 0
    set primitive_defs 0
    set part [expr {[catch {current_design}] ? "xc7k70tfbg484" : [get_property PART [current_design]]}]
    set tile ""
    set max_processes [get_param general.maxThreads]
    set file ""
    # Parse the arguments
    ::tincr::parse_args {tile part max_processes} {brief primitive_defs} {file} {} $args
    
    if {$file == ""} {set file "${part}_[expr {$brief ? "brief" : "full"}].xdlrc"}
    
    if {$tincr::debug} {
        puts "tile: $tile"
        puts "part: $part"
        puts "max_processes: $max_processes"
        puts "brief: $brief"
        puts "primitive_defs: $primitive_defs"
        puts "file: $file"
    }
        
    set start_time [clock seconds]
    puts "Process began at [clock format $start_time -format %H:%M:%S] on [clock format $start_time -format %D]"
    
    # set a flag if the XDLRC is for series7 devices
    set is_series7 [expr {[string first "7" [get_property ARCHITECTURE [get_parts $part]]] != -1}]
    
    tincr::run_in_temporary_project -part $part {
        # Declare a semaphore to restrict the number of concurrent processes to "max_processes"
        # This has to be global so that the process handler can access it
        global _TINCR_XDLRC_PROCESS_COUNT
        set _TINCR_XDLRC_PROCESS_COUNT 0
            
        # Open the XDLRC file
        set outfile [open $file w]
        fconfigure $outfile -translation binary
        
        # Write file header
        puts $outfile "# ======================================================="
        puts $outfile "# XDL REPORT MODE \$Revision: 1.8 \$"
        puts $outfile "# time: [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y"]"
        puts $outfile "# cmd: ::tincr::write_xdlrc $args"
        puts $outfile "# ======================================================="
        puts $outfile "(xdl_resource_report v0.2 [get_property NAME [get_parts $part]] [get_property FAMILY [get_parts $part]]"
        puts $outfile "# **************************************************************************"
        puts $outfile "# *                                                                        *"
        puts $outfile "# * Tile Resources                                                         *"
        puts $outfile "# *                                                                        *"
        puts $outfile "# **************************************************************************"
        
        # Write tiles tag
        puts $outfile "(tiles [tiles num_rows] [tiles num_cols]"
        
        # Create a temporary folder for the child processes to dump their data
        set tmpDir ".Tincr/xdlrc/$part"
        file mkdir $tmpDir
        
        if {$tile!= ""} {
            write_xdlrc_tile [get_tiles $tile] $outfile $brief $is_series7
        } else {
            set tiles [get_tiles]
            set num_tiles [llength $tiles]
            set tile_intrvl [expr {$brief ? [expr ($num_tiles / $max_processes) + 1] : 500}]
            
            set tile_files [list]
            
            set process_counter 0
            
            for {set start_tile 0} {$start_tile < $num_tiles} {incr start_tile $tile_intrvl} {
                # Calculate the set of tiles that will be generated in this process
                set end_tile [expr $start_tile + ($tile_intrvl - 1)]
                if {$end_tile >= $num_tiles} {
                    set end_tile [expr $num_tiles - 1]
                }
                
                # Set the path for a temporary tile dump directory
                set path "${tmpDir}/tiles_${start_tile}-${end_tile}.dat"
                lappend tile_files $path
                
                # Wait for at least one running process to finish
                while {$_TINCR_XDLRC_PROCESS_COUNT >= $max_processes} {
                    vwait _TINCR_XDLRC_PROCESS_COUNT
                }
                
                # If more than max_processes processes are being created, that means that at least one process has completed
                puts -nonewline "\rPercent complete: [expr (($process_counter < $max_processes ? 0 : $process_counter - $max_processes) * $tile_intrvl * 100) / $num_tiles]%"
                
                # Create a new Vivado process and send it a set of commands
                set p [open |[list vivado -mode tcl] w+]
                incr _TINCR_XDLRC_PROCESS_COUNT 1
                fconfigure $p -blocking 0
                fileevent $p readable [list ::tincr::process_handler $p]
                puts $p "package require tincr"
                puts $p "link_design -part $part"
                puts $p "set outfile \[open \"$path\" w\]"
                puts $p "set tiles \[get_tiles\]"
                puts $p "for \{set i $start_tile\} \{\$i <= $end_tile\} \{incr i\} \{"
                puts $p "tincr::write_xdlrc_tile \[lindex \$tiles \$i\] \$outfile $brief $is_series7"
                puts $p "flush \$outfile"
                puts $p "\}"
                puts $p "close \$outfile"
                puts $p "exit"
                flush $p
                
                incr process_counter
            }
            
            # Wait for all child processes to complete
            while {$_TINCR_XDLRC_PROCESS_COUNT > 0} {
                vwait _TINCR_XDLRC_PROCESS_COUNT
                puts -nonewline "\rPercent complete: [expr (($process_counter - $_TINCR_XDLRC_PROCESS_COUNT) * $tile_intrvl * 100) / $num_tiles]%"
            }
            
            # Stitch the tile data files together
            foreach tile_file $tile_files {    
                set infile [open $tile_file]
                #fconfigure $infile -translation binary
                fcopy $infile $outfile
                close $infile
            }
        }
        
        puts $outfile ")"
                
        # Newline
        puts "\rPercent complete: 100%"
        
        set site_types [::tincr::sites get_types [get_sites]]
    
        if {$primitive_defs} {
            # Primitive Definitions
            
            # For ultrascale devices add power/ground source sites that aren't explicitly represented in Vivado
            if {$is_series7 == 0} {
                lappend site_types "VCC" "GND"
            }
            
            puts $outfile "(primitive_defs [llength $site_types]"
            
            # Append primitive definitions
            foreach site_type [lsort $site_types] {
                set prim_def_file [file join [::tincr::cache::directory_path dict.site_type.src_bel.src_pin.snk_bel.snk_pins] "$site_type.def"]
                
                #throw an error if a site type doesn't have a corresponding definition
                if { ![file exists $prim_def_file] } {
                    error "ERROR: $site_type primitive definition not found! Please add this file and rerun." 
                }
                
                #appending the .def file to the end of the output stream.      
                set infile [open $prim_def_file]
                fconfigure $infile -translation binary
                fcopy $infile $outfile
                close $infile
                puts $outfile "" ; # put a new line between primitive defs
            }
            
            puts $outfile ")"
        }
        
        puts $outfile "# **************************************************************************"
        puts $outfile "# *                                                                        *"
        puts $outfile "# * Summary                                                                *"
        puts $outfile "# *                                                                        *"
        puts $outfile "# **************************************************************************"
        puts $outfile "(summary tiles=[llength [get_tiles]] sites=[expr [join [get_property NUM_SITES [get_tiles]] +]] sitedefs=[llength $site_types])"
        puts $outfile ")"
        
        # Close the XDLRC file
        close $outfile
        
        # Delete the intermediate files
        file delete -force $tmpDir
        
        # Unallocate the semaphore
        unset _TINCR_XDLRC_PROCESS_COUNT
    }
    
    set end_time [clock seconds]
    puts "Process ended at [clock format $end_time -format %H:%M:%S] on [clock format $end_time -format %D]"
}

proc ::tincr::write_xdlrc_tile { tile outfile brief is_series7 } {
    set sites [lsort [get_sites -quiet -of_object $tile]]
    
    set gnd_sources [list] 
    set vcc_sources [list] 
    if {$is_series7 == 0} {
        set gnd_sources [get_wires -of $tile -filter {NAME=~*/GND_WIRE*} -quiet]
        set vcc_sources [get_wires -of $tile -filter {NAME=~*/VCC_WIRE*} -quiet]
    }
    
    set num_sites [expr {[llength $sites] + [llength $gnd_sources] + [llength $vcc_sources]}]
    # TODO Fix this line of output
    puts $outfile "\t(tile [get_property ROW $tile] [get_property COLUMN $tile] [get_property NAME $tile] [get_property TYPE $tile] $num_sites"
#    [get_property NUM_SITES $tile]"
    
    set wires [list]
    set null_cnt 0
    
#    puts "Printing primitive site information..."
    set num_pins 0
    foreach site $sites {
        set state "internal"
        set name [get_property NAME $site]
        if {[get_property IS_PAD $site]} {
            if {[get_property IS_BONDED $site]} {
                set state "bonded"
                # Only use the PACKAGE PIN name for series7 devices.
                if {$is_series7} {
                    set name [get_property NAME [get_package_pins -quiet -of_object $site]]
                }
            } else {
                set state "unbonded"
            }
        }
    
        puts -nonewline $outfile "\t\t(primitive_site $name [get_property -quiet SITE_TYPE $site] $state [get_property -quiet NUM_PINS $site]"
        
        if {$brief == 0} {
            puts $outfile ""
            set site_pins [lsort [get_site_pins -quiet -of_object $site]]
    
            foreach site_pin $site_pins {
                set direction "?"
                if {[get_property IS_INPUT $site_pin]} {
                    set direction "input"
                } elseif {[get_property IS_OUTPUT $site_pin]} {
                    set direction "output"
                }
    
                set pin_name [tincr::site_pins get_info $site_pin name]
    
                set site_pin_wire "NULL"
                set site_pin_node [get_nodes -quiet -of_object $site_pin]
    
                set wire_name "NULL"
    
                #This means that the pin is on an edge tile, and has no node - it still has a wire though
                if {$site_pin_node == "" } {
                    # When the pin has no node, it isn't possible to find what wire it connects to. Since the wire doesn't go anywhere, we can just create a fake one.
                    set wire_name "TINCR_FAKE_[get_property NAME $tile]_$null_cnt"
                    lappend wires "\t\t(wire $wire_name 0)"
                    incr null_cnt
                } else {
                    if {[get_property IS_INPUT $site_pin]} {
                        set site_pin_wire [get_wires -of_object $site_pin_node -filter IS_INPUT_PIN]
                    } elseif {[get_property IS_OUTPUT $site_pin]} {
                        set site_pin_wire [get_wires -of_object $site_pin_node -filter IS_OUTPUT_PIN]
                    }
                    set wire_name [::tincr::wires get_info $site_pin_wire name]
                }
    
                puts $outfile "\t\t\t(pinwire $pin_name $direction $wire_name)"
            }
                        
            puts -nonewline $outfile "\t\t"
        }
    
        puts $outfile ")"
    
        incr num_pins [get_property NUM_PINS $site]
    }
    
    # print GND and VCC primitive sites for ultrascale devices and later
    set i 0
    foreach gnd_source $gnd_sources {
        regexp {.*_(X.*)/(.*)} $gnd_source -> tile_offset wire_name
        set site_name "GND_${tile_offset}_$i"
        puts -nonewline $outfile "\t\t(primitive_site $site_name GND internal 1"
        
        if {$brief == 0} {
            puts $outfile "\n\t\t\t(pinwire HARD0 output $wire_name)"
            puts -nonewline $outfile "\t\t"
        }    
        puts $outfile ")"
        incr i
    }
    
    set i 0
    foreach vcc_source $vcc_sources {
        regexp {.*_(X.*)/(.*)} $vcc_source -> tile_offset wire_name
        set site_name "VCC_${tile_offset}_$i"
        puts -nonewline $outfile "\t\t(primitive_site $site_name VCC internal 1"
        
        if {$brief == 0} {
            puts $outfile "\n\t\t\t(pinwire HARD1 output $wire_name)"
            puts -nonewline $outfile "\t\t"
        }    
        puts $outfile ")"
        incr i
    }
    
    # print wire information
    if {$brief == 0} {
#        puts "Printing wire information..."
#        set wires [lsort [get_wires -quiet -of_object $tile -filter {COST_CODE!=0}]]
        
        foreach wire $wires {
            puts $outfile $wire
        }
        
#        set wires [list]
#        foreach wire [get_wires -quiet -of_objects $tile] {
#            if {[does_node_exist [get_nodes -quiet -of_objects $wire]]} {
#                lappend wires $wire
#            }
#        }
        # TODO The line below (instead of the preceding 6 lines) make this XDLRC file a super-set of ISE's XDLRC
        set wires [get_wires -quiet -of_objects $tile]
    
    
        foreach wire $wires {
            set conns [lsort [get_wires -quiet -of_objects [get_nodes -quiet -of_objects $wire] -filter "TILE_NAME!=$tile"]]
    
            puts -nonewline $outfile "\t\t(wire [::tincr::wires get_info $wire name] [llength $conns]"
            if {[llength $conns] > 0} {
                puts $outfile ""
                foreach conn $conns {
                    puts $outfile "\t\t\t(conn [get_property -quiet TILE_NAME $conn] [::tincr::wires get_info $conn name])"
                }
                puts -nonewline $outfile "\t\t"
            }
            puts $outfile ")"
        }
        
#        puts "Printing PIP information..."
        set pips [lsort [get_pips -quiet -of_objects $tile -filter {!IS_TEST_PIP && !IS_EXCLUDED_PIP}]]
        foreach pip $pips {
            set uphill_node [get_nodes -quiet -uphill -of_object $pip]
            set downhill_node [get_nodes -quiet -downhill -of_object $pip]
    
            if {$uphill_node != "" && $downhill_node != ""} {
#                set direction [::tincr::pips get_info $pip direction]
                set direction "->"
                set route_through ""
                
                # If it's PSEUDO then it's a route through?
                if {[get_property IS_PSEUDO $pip]} {
                    set direction "->"
                    set src_pin [get_site_pins -of_object [get_nodes -uphill -of_object $pip]]
                    set snk_pin [get_site_pins -of_object [get_nodes -downhill -of_object $pip]]
                    set route_through " (_ROUTETHROUGH-[::tincr::site_pins get_info $src_pin name]-[::tincr::site_pins get_info $snk_pin name] [get_property SITE_TYPE [get_sites -of_object $src_pin]])"
                } elseif {[::tincr::pips get_info $pip direction] == "<<->>"} {
                    set direction "=-"
                    puts $outfile "\t\t(pip [get_property TILE $pip] [::tincr::pips get_info $pip output] $direction [::tincr::pips get_info $pip input])"
                }
    
                puts $outfile "\t\t(pip [get_property TILE $pip] [::tincr::pips get_info $pip input] $direction [::tincr::pips get_info $pip output]$route_through)"
            }
        }
        
        puts $outfile "\t\t(tile_summary [get_property NAME $tile] [get_property TILE_TYPE $tile] $num_pins [llength $wires] [get_property NUM_ARCS $tile])"
    }
    
    puts $outfile "\t)"
}

## Appends the primitive definition corresponding to <CODE>site_type</CODE> of the current device to the output stream provided by <CODE>output</CODE>.
# @param site_type The site type of the corresponding primitive definition.
# @param outfile The output stream that the primitive definition is to be written to.
proc ::tincr::append_primitive_def {site_type outfile} {
    set prim_def_file [file join $::env(TINCR_PATH) device_files primitive_definitions [get_property ARCHITECTURE [get_property PART [current_design]]] ${site_type}.def]
    
    #throw an error if a site type doesn't have a corresponding definition
    if { ![file exists $prim_def_file] } {
        error "ERROR: $site_type primitive definition not found! Please add this file and rerun." 
    }
    
    #appending the .def file to the end of the output stream.      
    set readFile [open $prim_def_file]
    puts $outfile [read $readFile]
    close $readFile     
}

## Appends all primitive defs of the current part to the end of a specified file.
# @param filename Where to write the primitive definitions.
# @param part Part to generate the primitive definitions for.
# @param append Append to the existing file.
proc ::tincr::write_primitive_defs { args } {
    set append 0
    set part ""
    set missing_prim_defs 0
    
    ::tincr::parse_args {} {append} {part} {filename} $args
    
    #Code that will be executed from "run_in_temporary_project"
    set append_primitive_defs  {
        
        #assuming that you ran write_xdlrc from the directory with all the primitive sites located
        set directory [get_property ARCHITECTURE [get_property PART [current_design] ] ]
            
        #throw an error if a site type doesn't have a corresponding definition
        dict for {site_type site} [::tincr::sites unique] {
            if { ![file exists $directory[file separator]$site_type.def ] } {
                puts "ERROR: $site_type primitive definition not found! Please add this file and rerun." 
                set missing_prim_defs 1
                break
            }
        }
        
        #if all site types have a definition, append each primitive definition
        if { !$missing_prim_defs } {
                
            if { $append == 1 } { ; #append to an existing file...assuming that a file handle has been passed into the function
                set write_file $filename
            } else { ; #create a new file
                set write_file [open $filename w]
            }
               
            #extracting the .def files into a list and sorting them alphabetically
            set prim_def_files [lsort -ascii [glob -directory $directory *.def]] 
            
            puts $write_file "(primitive_defs [llength $prim_def_files]"
                
            #appending each of the .def files to the end of the specified file.      
            foreach {prim_def} $prim_def_files {
                set readFile [open $prim_def]
                puts $write_file [read $readFile]
                close $readFile     
            }
            puts -nonewline $write_file ")\n"
            
            if { $append == 0 } {
                close $write_file
            }
        }
    } 

    #Running "append_primitive_defs" in a temporary project 
    if { $part == "" } {
        ::tincr::run_in_temporary_project $append_primitive_defs
    } else { 
        ::tincr::run_in_temporary_project -part $part $append_primitive_defs
    }
}

## Produce a partial .def file for the given primitive site. All config strings will be put inside of bel elements.
#   For Single Bel Sites (Sites where one BEL has over 80% of all bel pins in the site), some connections will be
#   automatically inferred and generated.
#
# @param site The <CODE>site</CODE> object you want to create a .def file for. Sites instanced by alternate types are acceptable.
# @param filename The output file.
# @param includeConfigs A boolean telling the proc whether or not to include configuration elements in the resulting .def file.
proc ::tincr::write_partial_primitive_def { site filename {includeConfigs 0} } {
    set site [get_sites $site]
    set site_name [get_property NAME $site]
    set outfile   [open $filename w]
    set alternate 0
    
    set site_pins [get_site_pins -of $site -quiet]
    set bels [get_bels -of $site -quiet]
    set site_pin_names [list]
    set num_elements [ expr { [llength $site_pins] + [llength $bels] } ]
        
    # Look for "Single Bel Sites" and try to generate as many connections as possible automatically
    set is_single_bel_site 0
    set pin_maps [list]
    if {[llength $bels] == 1} {
        set is_single_bel_site 1
        set pin_maps [get_single_bel_pin_maps $site [lindex $bels 0]]
    } else {
        set num_bel_pins_site [llength [get_bel_pins -of $site -quiet]]
        
        foreach bel $bels {
            set num_bel_pins_bel [llength [get_bel_pins -of $bel -quiet]]
            
            # if a single bel in a site contains 80% of all bel pins in the site, mark it as a single bel site
            if {[expr {double($num_bel_pins_bel) / double($num_bel_pins_site)}] > .800} {
                set is_single_bel_site 1
                set pin_maps [get_single_bel_pin_maps $site $bel]
                break
            }
        }
    }
    # maps holding bel_pin -> site_pin connections and vice versa
    set bel_pin_to_site_pin_map [lindex $pin_maps 0]
    set site_pin_map [lindex $pin_maps 1]
    
    #Header NOTES:
    # 1.) For now, the number of elements found at the top of a primitive definition is temporarily 0 (overridden once all of the elements have been counted)  
    # 2.) DO NOT delete the white spaces after the 0.  They are necessary when overwriting this line)  
    puts $outfile "\t(primitive_def [get_property SITE_TYPE $site] [llength $site_pins] 0             " ; #Elements"
    
    # **************************************************************************
    # *                                                                        *
    # * Pin Resources:                                                         *
    # *                                                                        *
    # **************************************************************************
    
    foreach pin $site_pins {
    
        set name [get_property NAME $pin ]
        
        set rel_name [string range $name [string wordend $name [string first "/" $name]] end] 
        
        if { [get_property IS_INPUT $pin] == 1 } { 
            set external_dir "input"
        } elseif { [get_property IS_OUTPUT $pin] == 1 } {    
            set external_dir "output" 
        } else {    
            set external_dir "inout"
        }
        #may not need the inout above for site pins 
        puts $outfile "\t\t(pin $rel_name $rel_name $external_dir)"
        lappend site_pin_names $rel_name
    }    
    
    foreach pin $site_pins {
    
        set name [get_property NAME $pin ]
        
        set rel_name [string range $name [string wordend $name [string first "/" $name]] end] 
        
        if { [get_property IS_INPUT $pin] == 1 } { 
            set dir_string "==>"
            set internal_dir "output"
        } elseif { [get_property IS_OUTPUT $pin] == 1 } {    
            set internal_dir "input"
            set dir_string "<=="
        } else {
            set internal_dir "inout"
            set dir_string "==>"
        }
        
        puts $outfile "\t\t(element $rel_name 1"
        puts $outfile "\t\t\t(pin $rel_name $internal_dir)"
        
        # (conn CE_INT0 CE_INT0 ==> CEINV0 CE_PREINV)
        if { $is_single_bel_site == 1 && [dict exists $site_pin_map $pin] } {
            set ref_pin_name [lindex [split $pin "/"] 1]
            set bel_pin [split [dict get $site_pin_map $pin] "/"]
            set bel_name [lindex $bel_pin 1]
            set bel_pin_name [lindex $bel_pin 2]
            puts $outfile "\t\t\t(conn $ref_pin_name $ref_pin_name $dir_string $bel_name $bel_pin_name)"
        }
        puts $outfile "\t\t)"
        
    }
    # *******************************************************************************
    # *                                                                             *
    # * Site PIP Resources:                                    *
    # * Site PIP Properties: CLASS, FROM_PIN, IS_FIXED, IS_USED, NAME, SITE, TO_PIN *
    # * Getting property "IS_FIXED" from vivado crashes application                 *
    # *                                                                             *
    # *******************************************************************************
    
    set site_pips [get_site_pips -of $site -quiet] ; #crashes vivado if the site is an alternate site type :(
    set unique_site_pips [dict create]
    
    foreach pip $site_pips {
    
        set first [expr {[string first "/" [get_property NAME $pip]] + 1} ]
        set last  [expr {[string first ":" [get_property NAME $pip]] - 1} ]
        set pip_name [string range [get_property NAME $pip] $first $last]
        
        dict set unique_site_pips $pip_name [get_property NAME $pip] 1 
    }
    
    dict for {pip_name pip_list} $unique_site_pips {
    
        if { [lsearch $bels "$site_name/$pip_name"] == -1 } {
            
            incr num_elements
            puts $outfile "\t\t(element $pip_name [ expr { [llength $pip_list]/2 + 1 }]"
            puts $outfile "\t\t\t(pin [get_property TO_PIN [get_site_pips -of $site [lindex $pip_list 0]]] output)"
            dict for {unique_name count} $pip_list {
                
                puts $outfile "\t\t\t(pin [get_property FROM_PIN [get_site_pips -of $site $unique_name]] input)"
                
            }
            puts -nonewline $outfile "\t\t\t(cfg"
            dict for {unique_name count} $pip_list {
                        
                puts -nonewline $outfile " [get_property FROM_PIN [get_site_pips -of $site $unique_name]]"
            }
            puts $outfile ")"
            puts $outfile "\t\t)"
            
        } else {
            #Just ignore for now...I don't think these are important
        }
    }    
    
    # **************************************************************************
    # *                                                                        *
    # * Bel Resources: (element <NAME> <Number of Pins> # BEL                  *
    # *                     (pins....)                            *
    # *            (cfg ....)                                         *
    # *                                                                        *
    # **************************************************************************
    
    # Some BELs that are shown in the Vivado Design Browser are not returned
    # from the function call [get_bels -of $site] because they are "TEST" BELs.
    # Instead, we create a belname -> bel pins map to find all BELs in the site. 
    set bel_pin_map [dict create]
    foreach bel_pin [get_bel_pins -of $site] {
        regexp {.+/(.+)/.+} [get_property NAME $bel_pin] -> bel_name
        dict lappend bel_pin_map $bel_name $bel_pin
    }
    # Some BELs have no pins, so add those to the map with an empty list of pins  
    foreach bel_no_pins [get_bels -of $site -filter NUM_PINS==0 -quiet] {
        set rel_name [lindex [split $bel_no_pins "/"] end]
        dict set bel_pin_map $rel_name [list] 
    }

    dict for {bel_name bel_pins} $bel_pin_map {
        
        puts -nonewline $outfile "\t\t(element $bel_name [llength $bel_pins] # BEL"
        
        # Mark Test BELs with the "TEST" label
        if {[llength [get_bels -of $site "$site/$bel_name" -quiet]] == 0} {
            puts $outfile " TEST"
            incr num_elements 
        } else {
            puts $outfile ""
        }         
        
        # Print the bel pin information
        set connection_list [list]
        
        foreach pin $bel_pins {
            
            set name [get_property NAME $pin ]
            
            set rel_name [string range $name [string last "/" $name]+1 end] 
            
            if { [get_property IS_OUTPUT $pin] == 1 } { 
                set dir "output"
                set dir_string "==>"
            } elseif { [get_property IS_INPUT $pin] == 1 } {    
                set dir "input"
                set dir_string "<=="
                
            } else {    
                set dir "inout"
                set dir_string "<=="
            }
            
            puts $outfile "\t\t\t(pin $rel_name $dir)"    
            
            # (conn CE_INT0 CE_INT0 ==> CEINV0 CE_PREINV)
            if { $is_single_bel_site == 1 && [dict exists $bel_pin_to_site_pin_map $pin] } {
                set ref_pin_name [lindex [split [dict get $bel_pin_to_site_pin_map $pin] "/"] 1]
                
                set bel_pin [split $pin "/"]
                set bel_name [lindex $bel_pin 1]
                set bel_pin_name [lindex $bel_pin 2]
                lappend connection_list "\t\t\t(conn $bel_name $bel_pin_name $dir_string $ref_pin_name $ref_pin_name)"
            }   
        }
        
        # Print the single bel connections if any exist
        foreach single_bel_connection $connection_list {
            puts $outfile $single_bel_connection
        }
        
        set cfgs  [list]
        set attrs [list]
        
        if { $includeConfigs == 1 } { 
            #Bel Config Strings
            foreach property [lsearch -all -inline [list_property $bel] CONFIG.*.VALUES] {
                regexp {CONFIG.(\w+).VALUES} $property matched attr
                
                
                set values [regexp -inline -all -- {\w+} [get_property $property $bel]]
                
                if { [llength $values] == 0 } {
                    puts -nonewline $outfile "\t\t\t(cfg"
                    puts $outfile " <$attr>)"
                } else {
                    
                    lappend cfgs $values 
                    lappend attrs $attr
                }
            }
            
            puts $outfile "\t\t)"
            
            set index 0
            foreach cfg $cfgs {
            
                puts $outfile "\t\t(element [lindex $attrs $index] 0 #[string range $bel_name [string wordend $bel_name [string first "/" $bel_name]] end]"
                puts -nonewline $outfile "\t\t\t(cfg"
                foreach option $cfg {
                
                    puts -nonewline $outfile " $option" 
                }
                puts $outfile ")"
                puts $outfile "\t\t)"
                incr index
                incr num_elements
            }
        } else {
            puts $outfile "\t\t)"    
        }
    }
    
    # **************************************************************************
    # *                                                                        *
    # * RouteThrough Information: (element _ROUTETHROUGH-IN-OUT                *
    # *                             (pins....)                         *
    # *                            )                                           *
    # **************************************************************************
    if { !$alternate } {
    
        set rt_pips  [get_pips -of [get_tiles -of $site] -filter {IS_PSEUDO==1}  -quiet]
        set routethroughs [dict create]
        
        foreach rt_pip $rt_pips {
            
            set pip_name [get_property NAME $rt_pip]
            set arrow_index [string first "->>" $pip_name]
            
            set in_pin  [string range $pip_name 0 [expr { $arrow_index - 1 }] ]
            set out_pin [string range $pip_name $arrow_index end]
            set in_pin  [string trim [string range $in_pin [expr { [string last "_" $in_pin] + 1} ] end]]
            set out_pin [string trim [string range $out_pin [expr { [string last "_" $out_pin] + 1} ] end]]
            
            if { [lsearch $site_pin_names $in_pin] != -1 && [lsearch $site_pin_names $out_pin] != -1 } {
                dict set routethroughs $in_pin $out_pin 1 
            }
        }
        dict for {in tmp} $routethroughs {
            
            dict for {out count} $tmp {
                incr num_elements
                puts $outfile "\t\t(element _ROUTETHROUGH-$in-$out 2"
                puts $outfile "\t\t\t(pin $in input)"
                puts $outfile "\t\t\t(pin $out output)"
                puts $outfile "\t\t)"
            }
        }
    }
    
    #Writing the last ")" and closing the file stream 
    puts -nonewline $outfile "\t)\n"
    flush $outfile

    #rewriting the first line in the file to include the number of elements that I could get from vivado
    #(need this info for the primitive def parser to work properly)
    
    if {$is_single_bel_site == 1} {
        set mode "#SBS"
    } else {
        set mode ""
    }
    
    seek $outfile 0 start
    puts -nonewline $outfile "\t(primitive_def [get_property SITE_TYPE $site] [llength $site_pins] $num_elements $mode" ; #Elements"
    close $outfile
}

## Creates a "VCC.def" primitive definition for use in Ultrascale and later devices.
#   This site does not actually exist on ultrascale parts, but is needed to create
#   more accurate device descriptions.
#
# @param directory Directory to create the "VCC.def" file in
proc ::tincr::write_vcc_primitive_def { directory } {
    
    if { [file isdirectory $directory] == 0 } {
        puts "$directory is not a valid directory location"
        return
    }
    
    set outfile [open [file join $directory "VCC.def"] w]
    
    
    puts $outfile "\t(primitive_def VCC 1 2"
    puts $outfile "\t\t(pin HARD1 HARD1 output)"
    puts $outfile "\t\t(element HARD1 1"
    puts $outfile "\t\t\t(pin HARD1 input)"
    puts $outfile "\t\t\t(conn HARD1 HARD1 <== HARD1VCC P)"
    puts $outfile "\t\t)"
    puts $outfile "\t\t(element HARD1VCC 1 # BEL"
    puts $outfile "\t\t\t(pin P output)"
    puts $outfile "\t\t\t(conn HARD1VCC P ==> HARD1 HARD1)"
    puts $outfile "\t\t)"
    puts -nonewline $outfile "\t)"
    close $outfile
}

## Creates a "GND.def" primitive definition for use in Ultrascale and later devices.
#   This site does not actually exist on ultrascale parts, but is needed to create
#   more accurate device descriptions.
#
# @param directory Directory to create the "GND.def" file in
proc ::tincr::write_gnd_primitive_def { directory } {
    
    if { [file isdirectory $directory] == 0 } {
        puts "$directory is not a valid directory location"
        return
    }
    
    set outfile [open [file join $directory "GND.def"] w]
    
    puts $outfile "\t(primitive_def GND 1 2"
    puts $outfile "\t\t(pin HARD0 HARD0 output)"
    puts $outfile "\t\t(element HARD0 1"
    puts $outfile "\t\t\t(pin HARD0 input)"
    puts $outfile "\t\t\t(conn HARD0 HARD0 <== HARD0GND G)"
    puts $outfile "\t\t)"
    puts $outfile "\t\t(element HARD0GND 1 # BEL"
    puts $outfile "\t\t\t(pin G output)"
    puts $outfile "\t\t\t(conn HARD0GND G ==> HARD0 HARD0)"
    puts $outfile "\t\t)"
    puts -nonewline $outfile "\t)"
    close $outfile
}

## Get the minimum set cover of parts that together contain all of the possible site types for the list of given parts.
# @param parts The set of parts that comprise the universal set of site types.
# @param trial The number of trials (default is 300).
# @return A subset of parts that comprise the universal set of site types.
proc ::tincr::get_primitive_def_cover_set {parts {trials 300}} {
    tincr::cache::get array.part.site_types myarray
    
    set site_types [list]
    set n [llength $parts]
    
    foreach part $parts {
        ::struct::set add site_types $myarray($part)
    }
    
    set solution [::simulation::annealing::findCombinatorialMinimum -parts $parts -n $n -site_types $site_types -myarray [array get myarray] -trials $trials  -verbose 0  -number-params $n -initial_values [::struct::list repeat $n 1]  -code {
        set result 0
        
        set parts [getOption parts]
        set n [getOption n]
        set site_types [getOption site_types]
        array set myarray [getOption myarray]
        
        set types [list]
        for {set i 0} {$i < $n} {incr i} {
            if {[lindex $params $i] == 1} {
                ::struct::set add types $myarray([lindex $parts $i])
                incr result
            }
        }
        
        if {![::struct::set equal $site_types $types]} {
            set result $n
        }
    }]
    
    set results [list]
    
    for {set i 0} {$i < $n} {incr i} {
        if {[lindex [dict get $solution solution] $i] == 1} {
            lappend results [lindex $parts $i]
        }
    }
    
    return $results
}

proc ::tincr::write_all_partial_primitive_defs { {includeConfigs 0} } {
    # Get a list of all architectures
    set architectures [list]
    foreach part [get_parts] {
        ::struct::set include architectures [get_property ARCHITECTURE $part]
    }
    
    # Now generate primitive definitions based on architecture
    foreach architecture $architectures {
        set prim_def_dir [file join $::env(TINCR_PATH) device_files primitive_definitions $architecture]
        file mkdir $prim_def_dir
        
        # Get a cover set of parts for this architecture
        set parts [get_primitive_def_cover_set [get_parts -filter "ARCHITECTURE==$architecture"]]
        
        # Process these parts
        foreach part $parts {
            ::tincr::run_in_temporary_project -part $part {
                ::tincr::cache::get array.site_type.sites sitetype2sites
                
                foreach type [array names sitetype2sites] {
                    puts $type
                    if {$type == "IOB33" || $type == "IOB18" || $type == "ILOGICE2"} continue
                    
                    set site [lindex $sitetype2sites($type) 0]
                    
                    set prim_def_path [file join $prim_def_dir ${type}.def]
                    
                    if {[::tincr::sites get_type $site] != $type} {
                        ::tincr::sites set_type $site $type
                    }
                    
                    write_partial_primitive_def $site $prim_def_path $includeConfigs
                }
            }
        }
    }
}

## Produces a partial .def file for each primitive site of each part in the xilinx family. 
#   This function should be called only when a new xilinx series is released. The files
#   produced from this script are intended to be used by the VSRT tool of the RapidSmith2
#   repository.
#
#   NOTE: When the script is running, some warnings will be printed to the screen, but they can be ignored. 
#
# @param cfg Add this option if you want to include cfg strings in your primitive def files.
# @param path The path you want the family directories and files to be written to.
# @param arch Architecture to generate primitive defs for currently, possible options include
#  <p><ul>
#  <li> artix7 
#  <li> kintex7 
#  <li> virtex7 
#  <li> zynq 
#  <li> kintexu 
#  <li> kintexuplus
#  <li> virtexu 
#  <li> virtexuplus
#  <li> zynquplus
# </ul><p>
proc ::tincr::extract_all_partial_primitive_defs {path {arch ""} {includeConfigs 0}} {
    catch { close_project }
    
    set parts [tincr::get_parts_unique $arch]
    
    set archTypes [dict create]
    set altArchTypes [dict create]
    set partCount [llength $parts]
    set i 1
    set alternate "_ALTERNATE"
    
    #make the specified directory if it doesn't exist
    file mkdir $path
    
    #open logfile for writing
    set end "log.txt"
    set fileID [open [file join $path $end] "w"]
    
    #getting a list of unique family names, and a single part of that family type
    foreach prt $parts {
        
        set arch [get_property ARCHITECTURE $prt]

        file mkdir [file join $path $arch]
        
        puts "Extracting Primitive Sites from part [get_property NAME $prt] ($i out of $partCount)..."
        puts $fileID "Extracting Primitive Sites from part [get_property NAME $prt] ($i out of $partCount)..."
        link_design -part [get_property NAME $prt] -quiet ; #can take a long time
        
        set site_types [::tincr::sites unique 1]
        set site_type_map [lindex $site_types 0]
        set alternate_type_set [lindex $site_types 1]
        
        # Process the site types
        dict for {type site} $site_type_map {
            # Check to see if the current site is an alternate only type
            if { [::struct::set contains $alternate_type_set $type] } {
                if { ![dict exists $archTypes $arch $type] && ![dict exists $altArchTypes $arch $type] } {
                    dict set altArchTypes $arch $type 1
                    puts "\tALTERNATE: $arch-$type -> $site..."
                    puts $fileID "\tALTERNATE: $arch-$type -> $site..."
 
                    reset_property MANUAL_ROUTING $site
                    set_property MANUAL_ROUTING $type $site
                    write_partial_primitive_def $site [file join $path $arch ${type}${alternate}.def] $includeConfigs
                }
            } else {
                if { ![dict exists $archTypes $arch $type] } {
                    dict set archTypes $arch $type 1 
                    puts "\t$arch-$type -> $site..."
                    puts $fileID "\t$arch-$type -> $site..."
                    write_partial_primitive_def $site [file join $path $arch $type.def] $includeConfigs
                }
            }
        }
         
        close_project -quiet
        incr i 
    }
    
    #delete all alternate types that were found as a default types in another part
    dict for {arch alternates} $altArchTypes {
        dict for {altSiteType tmp} $alternates {
            if { [dict exists $archTypes $arch $altSiteType] } {
                puts [file join $path $arch ${altSiteType}${alternate}.def]
                file delete [file join $path $arch ${altSiteType}${alternate}.def]
            }            
        }
    }
    puts "Successfully created all .def files in directory $path"
    close $fileID
}

## Returns a list of unique parts, ignoring speed grade
#
# @param arch Optional architecture parameter. Only parts 
#   that match the specified architecture will be returned. 
#
proc ::tincr::get_parts_unique {{arch ""}} {
    set unique_part_set ""
    set part_list [list]
    
    if {$arch==""} {
        set parts [get_parts]
    } else {
        set parts [get_parts -filter ARCHITECTURE==$arch]
    }
    
    foreach part $parts {
        #remove speed grade from the part name
        regexp {^(x[a-z0-9]+(?:-[a-z0-9]+)?)-.+} $part -> partname
        
        if { ![::struct::set contains $unique_part_set $partname] } {
            ::struct::set add unique_part_set $partname
            lappend part_list $part
        }
    }
    
    return $part_list
}

## Creates a map of BEL Pin -> Site Pin (and vice versa) for sites that
#   are dominated by a single, large BEL
#
# @param site Site object
# @param bel Bel object within the {@link site}
# @param outfile Optional file handle for printing warnings to an output file
#
# @return A list of 2 maps:
#       Item 0: Map of Site Pin -> Bel Pin for the specified {@link site} and {@link bel}
#       Item 1: Map of Bel Pin -> Site Pin for the specified {@link site} and {@link bel}
proc get_single_bel_pin_maps {site bel} {

    foreach lib_cell [get_lib_cells] {

        set cell_instance [create_cell -reference $lib_cell cell -quiet]
        
        # look for the first cell we can place on the bel
        if {[catch {[place_cell $cell_instance $bel]} err] == 1} {
            remove_cell $cell_instance
            continue
        }

        # configure Block Ram cells to their max width before inferring connections
        set lib_cell [get_lib_cells -of $cell_instance]
        if { [get_property PRIMITIVE_GROUP $lib_cell] == "BMEM" } {
            unplace_cell $cell_instance -quiet
            config_bmem_to_max_width $cell_instance $lib_cell
            place_cell $cell_instance $bel -quiet            
        }
        
        # attach a net to each cell pin so that we can extract the connections
        attach_nets $cell_instance
        
        set lut_cell [create_cell -reference LUT6 lut6]
        set lut_site [lindex [get_sites -filter SITE_TYPE==SLICEL] 0]   
        place_cell $lut_cell $lut_site -quiet
    
        set bel_pin_map [dict create]
        set site_pin_map [dict create]
        
        # find the connections for each temporary net and add them to the maps
        foreach net [get_nets -of $cell_instance] {
            connect_net -net $net -objects [get_pins $lut_cell/O]
            
            set bel_pin [lindex [get_bel_pins -of $net] 0]
            set site_pin [lindex [get_site_pins -of $net] 0]
        
            if {[ string last "SLICE" $site_pin 5] == 0} {
                disconnect_net -net $net -objects [get_pins $lut_cell/O]
                continue
            }
            
            dict set bel_pin_map $bel_pin $site_pin
            dict set site_pin_map $site_pin $bel_pin
            disconnect_net -net $net -objects [get_pins $lut_cell/O]
        }
        
        remove_cell $lut_cell -quiet
        remove_net [get_nets -of $cell_instance -quiet] -quiet
        remove_cell $cell_instance -quiet
        
        return [list $bel_pin_map $site_pin_map]
    }
       
    puts "\t\tWARNING: Cannot infer single bel connections for site!"
}

## Configures the width of the specified Block Ram cell to its maximum (i.e the read and write width
#   of a RAMB36E2 will be set to 72 bits). This forces all cell pins to be mapped to BEL 
#   pins when the cell is placed and allows more primitive def connections to be automatically inferred.
#
# @param cell Cell instance
# @param lib_cell Library Cell that {@link cell} was created from
proc config_bmem_to_max_width { cell lib_cell } {
    # look at all of the cell's properties
    foreach property [list_property $lib_cell] {
        if { [regexp {CONFIG\.([^\.]+)\.DEFAULT$} $property -> prop_name] } {
            # Look for width parameters and set them to their max value
            if { [string first "WIDTH" $prop_name] != -1 } {
                set max [get_property CONFIG.${prop_name}.MAX $lib_cell]
                set_property $prop_name $max $cell 
            }
        }
    }
}