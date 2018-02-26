package provide tincr.io.device 0.0
package require Tcl 8.5
package require tincr.cad.design 0.0
package require tincr.cad.device 0.0
package require tincr.cad.util 0.0

namespace eval ::tincr:: {
    namespace export \
        create_xml_device_info \
}

## Creates a new device info XML in the specified directory for the specified 
#   part. Currently, the device info XML stores additional information about
#   pads in a device (i.e. clock pads and bel to package pin mappings). Other useful 
#   information may be added in the future. NOTE: any open projects will be closed
#   when this function is called.
#   
#   Example Usage: tincr::create_xml_device_info /home/ xcku025-ffva1156-1-c
#
#   This will create the file "/home/device_info_xcku025ffva1156.xml"
#   
#
# @param directory Directory to create the device info file in. If this parameter is not 
#   an existing directory, an error will be thrown. 
# @param partname Full partname of a Vivado device
proc ::tincr::create_xml_device_info { directory partname } {
    catch { close_project -quiet  }
    
    if { [file isdirectory $directory] == 0 } {
        puts "$directory is not a valid directory location"
        return
    }
    
    puts "Loading device..."
    # load the specified part in Vivado
    link_design -part $partname -quiet
    
    # create the output file in the form "device_info_modifiedpartname.xml" 
    # where the partname has been stripped of speedgrade and dash characters 
    set partname_no_speedgrade [tincr::remove_speedgrade $partname] 
    
    set dash_index [string first "-" $partname_no_speedgrade]
    if {$dash_index != -1} {
        set filename "deviceInfo_[string replace $partname_no_speedgrade $dash_index $dash_index].xml"
    } else { 
        set filename "deviceInfo_${partname_no_speedgrade}.xml"
    }
    
    # create the XML file
    set fileout [open [file join $directory $filename] w]
    
    # print the device info XML
    print_header_device_info $partname_no_speedgrade $fileout
    puts "Printing package pins..."
    print_package_pins $fileout
    
    puts $fileout "</device_info>"
    flush $fileout
    close $fileout
    
    puts "Successfully created [file join $directory $filename]" 
    close_project -quiet
}

## Prints the family info XML header
#
# @param partname_no_speedgrade Name of the part with the speedgrade removed
# @param fileout XML file handle
proc print_header_device_info {partname_no_speedgrade fileout} {
    # print XML header 
    puts $fileout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    puts $fileout "<device_info>"
    puts $fileout "  <partname>$partname_no_speedgrade</partname>"
}

## Prints package pin mappings for the currently opened part to the specified XML file.
#
# @param fileout XML file handle
proc print_package_pins { fileout } {
    set family [get_property ARCHITECTURE [get_parts -of [get_design]]]
    set is_series7 [tincr::parts::is_series7]
    
    puts $fileout "  <package_pins>"
    foreach site [get_sites -filter {IS_PAD && IS_BONDED}] {
        foreach bel [get_bels -of $site -filter TYPE=~*PAD*] {
            
            set package_pin [get_package_pins -of $bel]
            
            # Check that each bel only maps to exactly one package pin
            if {[llength $package_pin] != 1} {
                puts "Pad bel $bel should map to exactly 1 package pin. Instead, it maps to [llength $package_pin] package pins."
            }
            
            puts $fileout "    <package_pin>"
            puts $fileout "      <name>$package_pin</name>"
            
            if {$is_series7} {
                set ref_bel_name [lindex [split $bel "/"] end]  
                puts $fileout "      <bel>$package_pin/$ref_bel_name</bel>"
            } else {            
                puts $fileout "      <bel>$bel</bel>"
            }
            
            # mark clock pads
            if { [get_property IS_CLOCK_PAD $site -quiet] == "1" || [get_property IS_GLOBAL_CLOCK_PAD $site -quiet] == "1" } {
                puts $fileout "      <is_clock/>"
            }
            
            puts $fileout "    </package_pin>"
        }
    }
    puts $fileout "  </package_pins>"
}
