# Source-ing this file will create the basic familyInfo file called
# 'familyInfo_new.xml'.

# It will first output records for all primary types associated with
# physical sites.

# It will then output records for all the alternative types. Finally,
# it will output records for some that the regular logic doesn't
# catch.

#to generate the compatible sites...we have a dictionary to a list of compatible sites


# Things we currently can't automate with the script include:
# - alternate site pin mappings...this will have to be done by hand
# - invalid alternate sites will need to be removed by hand (determined by looking at the Vivado GUI)
#		this is also probably true for compatible sites that aren't really compatible
# - there is a list of sites that are not included in Vivado's TCL interface, a list will be kept 
#		in this script, and you will have to update it as needed

# If the bugs that cause these necessary automations every get fixed, we can re-implement the script to
#	get all of the information that we need


set family "ARTIX7"

proc createBlankDesignByPart { part } {
    return [tincr::designs new mydes $part]
}

# helper function used to get the relative name of Vivado elements 
proc suffix { s p } {
	return [lindex [split $s $p] end]
} 

#corrected version of the TINCR function that excludes anything other than dedicated routing BELS
proc get_routing_bel_names {site} {
	set bels [get_bels -of $site]
	set rmuxes [list]
	
	foreach pip [get_site_pips -of $site -quiet] {
		set name [lindex [split $pip ":"] 0]
		
		if {[lsearch $bels "$name"] == -1} {
			lappend rmuxes [lindex [split $name "/"] 1]
		}
	}
	
	return [lsort -unique $rmuxes]
}

#
#	The output of this function will be returned in the primary_sites, alternate_sites and compatible_sites 
#	variables of whoever called this function
#
proc uniqueSiteLists {primary_name alternate_name compatible_name} {
	#this simulates passing the arguments by reference,these variables need to be created before calling this function`
	upvar $primary_name primary
	upvar $alternate_name alternates
	upvar $compatible_name compatible
	
	#create empty dictionaries 
	set primary [dict create]
	set alternate_tmp [dict create]
	
	foreach site [get_sites] {
		# Create a dictionary of default site types
		if {![dict exists $primary [get_property SITE_TYPE $site]]} {
			dict set primary [get_property SITE_TYPE $site] $site
		}
		
		# Create a dictionary of alternate site types
		foreach type [get_property ALTERNATE_SITE_TYPES $site] {
					
			if {![dict exists $alternate_tmp $type]} {
				dict set alternate_tmp $type $site
			}
		}
	}
		
	# Create a dictionary of sites that are only alternates
	set alternates [dict create]
	dict for {type site} $alternate_tmp {
		if {![dict exists $primary $type] &&  ![regexp {.*IOB*} $type]} {
			dict set alternates $type $site
		}
	}
	
	# Build the candidate list of possible site location for each primitive 
	set compatible [dict create]
	dict for {sitename site} $primary {
		foreach alternate [get_property ALTERNATE_SITE_TYPES $site] {
			dict lappend compatible $alternate $sitename  
		}	
	}
}


proc putis {nam fo} {
	
    if {[string first SLICE $nam 0] == 0} then {
		puts $fo "      <is_slice/>"
    }
    if {[string first IOB $nam 0] == 0} then {
		puts $fo "      <is_iob/>"
    }
    if {[string first DSP $nam 0] == 0} then {
		puts $fo "      <is_dsp/>"
    }
    if {[string first RAMB $nam 0] == 0} then {
		puts $fo "      <is_bram/>"
    }
    if {[string first FIFO $nam 0] == 0} then {
		puts $fo "      <is_fifo/>"
    }
    if {[string first RAMBFIFO $nam 0] == 0} then {
		puts $fo "      <is_fifo/>"
    }
}

proc processSite {s type compatible is_alt fo} {

    puts $fo "    <primitive_type>"
    puts $fo "      <name>$type</name>"
    putis $type $fo

	#write compatible types information 
	if { [llength $compatible] != 0 } {
		puts $fo "      <compatible_types>"
		foreach comp $compatible {
			puts $fo "        <compatible_type>$comp</compatible_type>" 
		}
		puts $fo "      </compatible_types>"
	}
	
	# If the site is a primary type, then print the alternate site type information	
	if {$is_alt == 0} {		
		set alts [get_property ALTERNATE_SITE_TYPES $s]		
		if { [llength $alts] != 0 } {
			puts $fo "      <alternatives>"
			foreach alt $alts {
				puts $fo "        <alternative>"
				puts $fo "          <name>$alt</name>"
				puts $fo "          <pinmaps>"
				puts $fo "          </pinmaps>"
				puts $fo "        </alternative>"
			}
			puts $fo "      </alternatives>"
		}
	} else {
		# where the error is occurring
		set_property MANUAL_ROUTING $type $s
	}
	
	puts $fo "      <bels>"
	set pin_dir_corrections [dict create]
  
	foreach b [get_bels -of $s] {
		
		#look for inout pins ... these are not represented in the XDLRC file and so we have to add a correction
		foreach bp [get_bel_pins -of $b] {
			if { [get_property DIRECTION $bp] == "INOUT" } {
				dict lappend pin_dir_corrections [suffix $b "/"] [suffix $bp "/"]
			}
		}
		
		#print the bel information 
		set tmpname [suffix $b "/"]
		puts $fo "        <bel>"
		puts $fo "          <name>$tmpname</name>"
		puts $fo "          <type>$tmpname</type>"
		puts $fo "        </bel>"
	}
    puts $fo "      </bels>"

	puts $fo "      <corrections>"
			
	#print pin direction corrections 
	dict for {bel pins} $pin_dir_corrections {
		foreach pin $pins {
			puts $fo "        <pin_direction>"
			puts $fo "          <element>$bel</element>"
			puts $fo "          <pin>$pin</pin>"
			puts $fo "          <direction>inout</direction>"
			puts $fo "        </pin_direction>"
		}
	}
	
	#print any routing mux corrections
	foreach rbel [get_routing_bel_names $s] {
		if {[string range $rbel end-2 end] == "INV" } then {
			puts $fo "        <polarity_selector> <name>$rbel</name> </polarity_selector>"
		} else {
			puts $fo "        <modify_element>    <name>$rbel</name> <type>mux</type> </modify_element>"
		}
	}
	
	# make sure to reset the manual routing property if we previously changed it
	if {$is_alt == 1} {
		reset_property MANUAL_ROUTING $s 
	}
	
    puts $fo "      </corrections>"
    puts $fo "    </primitive_type>"
    puts $fo ""
}

proc printSingleBelPrimitiveList {sites fo} {

	foreach site $sites {
		puts $fo "    <primitive_type> "
		puts $fo "      <name>$site</name>"
		puts $fo "      <bels>"
		puts $fo "        <bel>"
		puts $fo "          <name>$site</name>"
		puts $fo "          <type>$site</type>"
		puts $fo "        </bel>"
		puts $fo "      </bels>"
		puts $fo "    </primitive_type>"
	}
}

 
#main function
proc createFamilyInfo { } {
	# open output file 
	createBlankDesignByPart xc7a100t-csg324-1 

	set fo [open "familyInfo_thomas.xml" w]

	# print XML header 
	puts $fo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	puts $fo "<device_description>"
	puts $fo "  <family>ARTIX7</family>"
	puts $fo "  <switch_matrix_types>"
	puts $fo "    <type>INT_L</type>"
	puts $fo "    <type>INT_R</type>"
	puts $fo "  </switch_matrix_types>"
	puts $fo "  <primitive_types>"

	# create the database of sites that we need
	set primary_sites [dict create]
	set alternate_sites [dict create]
	set compatible_sites [dict create]

	puts "Building the primitive site dictionaries..."
	uniqueSiteLists primary_sites alternate_sites compatible_sites
	
	# process the sites that are default types
	puts "Processing default site types..."
	dict for {site_type site} $primary_sites {
		if {[dict exists $compatible_sites $site_type] } {
			processSite $site $site_type [dict get $compatible_sites $site_type] 0 $fo
		} else {
			processSite $site $site_type [list] 0 $fo
		}
	}	

	#print sites that show up in Vivado, but don't actual exist via the TCL interface
	puts $fo "\n<!-- Do the site types that are only alternate sites -->\n"
	puts "Processing alternate site types..."
	# process the sites that are only alternates
	dict for {site_type site} $alternate_sites {
		if {[dict exists $compatible_sites $site_type] } {
			processSite $site $site_type [dict get $compatible_sites $site_type] 1 $fo
		} else {
			processSite $site $site_type [list] 1 $fo
		}
	}

	#print sites that show up in Vivado, but don't actual exist via the TCL interface
	puts $fo "\n<!-- Do the site types that don't appear in the tincr::sites::unique list -->\n"
	puts "Processing all other site types..."
	foreach s [tincr::sites::get_types] {
		
		if {![dict exists $primary_sites $s] && ![dict exists $alternate_sites $s] && ![dict exists $compatible_sites $s] } {
			printSingleBelPrimitiveList $s $fo 
		}	
	}

	# Do the site types that appear in the XDLRC as primitive sites that the TCL interface doesn't know about
	# NOTE: Update the list below as needed 
	puts $fo "\n\n\n<!-- Do the site types that appear in the XDLRC as primitive sites that aren't found in Vivado's TCL interface -->\n"

	set xdlrc_primitives [list CFG_IO_ACCESS GCLK_TEST_BUF MTBF2 PMV PMV2_SVT PMVBRAM PMVIOB]
	printSingleBelPrimitiveList $xdlrc_primitives $fo

	
	# Do the site types that are needed but show up nowhere ... why do we need this  
	# NOTE: Update the list below as needed 
	puts $fo "\n\n\n<!-- Do the site types that are needed but show up nowhere - not sure where they would come from so I add them here -->\n"

	set other [list DCI ]
	printSingleBelPrimitiveList $other $fo

	puts $fo "\n  </primitive_types>"
	
	#print the clock pads to the files
	
	#mark IO pads as clock pads so this information can be loaded into RS2 and used to properly place clk pads
	puts $fo "\n  <clock_pads>"
	
	set clock_pads [get_sites -filter {(IS_CLOCK_PAD || IS_GLOBAL_CLOCK_PAD) && IS_BONDED}]
	
	foreach pad $clock_pads {
		puts "    <site_name>[get_property NAME [get_package_pins -quiet -of_object $pad]]</site_name>"	
	}
	puts $fo "\n  </clock_pads>"	
	
	puts $fo "</device_description>"

	flush $fo
	close $fo
	
	puts "Successfully created familyInfo.xml!" 
	close_design	
} 

createFamilyInfo

