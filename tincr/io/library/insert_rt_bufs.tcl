
# Does there exist routethrough's in SLICEM sites? For now, I am ignoring these...
proc insert_routethrough_buffers { } {

	set letters [list "A" "B" "C" "D"]
	set l6 "6LUT"
	set l5 "5LUT"
	set ff5_pin "5FF/D"
	set ff_pin "FF/D"
	set mux "MUX"
		
	set lut5_carry_sinks [dict create]
	dict set lut5_carry_sinks "A" "CARRY4/DI0"   
	dict set lut5_carry_sinks "B" "CARRY4/DI1"   
	dict set lut5_carry_sinks "C" "CARRY4/DI2"   
	dict set lut5_carry_sinks "D" "CARRY4/DI3"    
		
	foreach site [get_sites -filter {IS_USED && SITE_TYPE == SLICEL}] {
		
		set sitename [get_property NAME $site]
		
		foreach letter $letters {
			set lut6 [get_bels -of $site "$sitename/$letter$l6"]
			set lut5 [get_bels -of $site "$sitename/$letter$l5"]
		
			set is_lut6_rt [is_lut_routethrough $lut6]
			set is_lut5_rt [is_lut_routethrough $lut5]
			
			if {$is_lut6_rt && !$is_lut5_rt} {
				
				if {![get_property IS_USED $lut5]} {				
					for {set i 1} {$i < 7} {incr i} {
						set pinname "$letter$i"
						set site_pin [get_site_pins "$sitename/$pinname"]
					
						if {[get_property IS_USED $site_pin] && [get_nets -of $site_pin] != ""} {
							set rt_pin "A$i"
							puts "ROUTETHROUGH FOUND: BEL: $lut6 PIN: $rt_pin"
						}	
					}
				} else {
					puts "!!ROUTETHROUGH FOUND: BEL: $lut6 PIN: !!"
				}
				
			} elseif {$is_lut5_rt && !$is_lut6_rt} {
			
				set rt_net ""
				set rt_pin [find_lut5_routethrough_pin $letter $lut5_carry_sinks $sitename rt_net]
				
				# an empty rt_pin indicates the LUT has an output equation of 0
				# TODO: Modify with LUT insertion later
				if {$rt_pin != ""} {
					puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"
				}
						
			} elseif {$is_lut6_rt && $is_lut5_rt} {
				
				set rt_net ""
				# find the lut5 route-through pin
				set rt_pin [find_lut5_routethrough_pin $letter $lut5_carry_sinks $sitename rt_net]
				
				# lut5 is not actually a route-through
				if {$rt_pin == ""} {
					for {set i 1} {$i < 7} {incr i} {
						set pinname "$letter$i"
						set site_pin [get_site_pins "$sitename/$pinname"]
						if {[get_property IS_USED $site_pin] && [get_nets -of $site_pin] != ""} {
							set rt_pin "A$i"
							puts "ROUTETHROUGH FOUND: BEL: $lut6 PIN: $rt_pin"
						}						
					}
				} else {
					puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"				
					for {set i 1} {$i < 7} {incr i} {
						set pinname "$letter$i"
						set site_pin [get_site_pins "$sitename/$pinname"]
						
						if { [get_property IS_USED $site_pin] } {
							set net [get_nets -of $site_pin]
							if {$net != ""} {
								if {$net !=  $rt_net} {
									set rt_pin "A$i"
									puts "ROUTETHROUGH FOUND: BEL: $lut6 PIN: $rt_pin"
								}
							}
						}
					}
				}
				#continue
			}			
		}
	}
}


# function that returns true if a lut is a routethrough
proc is_lut_routethrough { lut } {
	if {[get_property IS_USED $lut] == 0 && [get_nets -of $lut -quiet] != ""} {
		return 1
	}
	
	return 0
}

# TODO: Make lut5_carry_sinks a global variable?
proc find_lut5_routethrough_pin { letter lut5_carry_sinks sitename rt_net } {
	upvar 1 $rt_net r_net
	set ff5_pin "5FF/D"
	set ff_pin "FF/D"
	set mux "MUX"
	
	# go through each of the site pins and create a map from
	# the net attached to the site pin to the corresponding LUT bel pin 
	set net_to_pin_map [dict create] 
	for {set i 1} {$i < 7} {incr i} {
		set pinname "$letter$i"
		set site_pin [get_site_pins "$sitename/$pinname"]
		
		if { [get_property IS_USED $site_pin] } {
			set net [get_nets -of $site_pin]
			if {$net != ""} {
				dict set net_to_pin_map $net "A$i"  
			}
		}
	}

	# check each possible sink of the 05 output to see which net is the routethrough net
	set bel_sink "$letter$ff_pin"
	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$bel_sink"] -quiet] -quiet]
	if {[dict exists $net_to_pin_map $net]} {
		set r_net $net
		set rt_pin [dict get $net_to_pin_map $net]  
		return $rt_pin
	}

	set bel_sink "$letter$ff5_pin"
	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$bel_sink"] -quiet] -quiet]
	if {[dict exists $net_to_pin_map $net]} {
		set r_net $net 
		set rt_pin [dict get $net_to_pin_map $net]  
		return $rt_pin
	}

	set carry_sink [dict get $lut5_carry_sinks $letter]
	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$carry_sink"] -quiet] -quiet]
	if {[dict exists $net_to_pin_map $net]} {
		set r_net $net
		set rt_pin [dict get $net_to_pin_map $net]  
		return $rt_pin
	}
					
	set site_sink "$letter$mux"
	set net [get_nets -of  [get_site_pins "$sitename/$site_sink" -quiet] -quiet]
	if {[dict exists $net_to_pin_map $net]} {
		set r_net $net
		set rt_pin [dict get $net_to_pin_map $net]  
		return $rt_pin
	}
	
	return ""
}




#if {0} {
	# go through each of the site pins and create a map from
	# the net attached to the site pin to the corresponding LUT bel pin 
#	set net_to_pin_map [dict create] 
#	for {set i 1} {$i < 7} {incr i} {
#		set pinname "$letter$i"
#		set site_pin [get_site_pins "$sitename/$pinname"]
#		
#		if { [get_property IS_USED $site_pin] } {
#			set net [get_nets -of $site_pin]
#			if {$net != ""} {
#				dict set net_to_pin_map $net "A$i"  
#			}
#		}
#	}

	# check each possible sink of the 05 output to see which net is the routethrough net
#	set bel_sink "$letter$ff_pin"
#	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$bel_sink"] -quiet] -quiet]
#	if {[dict exists $net_to_pin_map $net]} {
#		set rt_pin [dict get $net_to_pin_map $net]  
#		puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"
#		continue
#	}

#	set bel_sink "$letter$ff5_pin"
#	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$bel_sink"] -quiet] -quiet]
#	if {[dict exists $net_to_pin_map $net]} {
#		set rt_pin [dict get $net_to_pin_map $net]  
#		puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"
#		continue
#	}

#	set carry_sink [dict get $lut5_carry_sinks $letter]
#	set net [get_nets -of [get_pins -of [get_bel_pins "$sitename/$carry_sink"] -quiet] -quiet]
#	if {[dict exists $net_to_pin_map $net]} {
#		set rt_pin [dict get $net_to_pin_map $net]  
#		puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"
#		continue
#	}
					
#	set site_sink "$letter$mux"
#	set net [get_nets -of  [get_site_pins "$sitename/$site_sink"] -quiet]
#	if {[dict exists $net_to_pin_map $net]} {
#		set rt_pin [dict get $net_to_pin_map $net]  
#		puts "ROUTETHROUGH FOUND: BEL: $lut5 PIN: $rt_pin"
#		continue
#	}
#}