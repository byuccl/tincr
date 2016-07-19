
set net [get_nets <const1>]

set tiles [get_tiles -of $net]

set switchbox_tile [lindex $tiles 1]
set route_string [string range [get_property ROUTE $net] 3 end-3]
set route_string "$switchbox_tile/$route_string"

puts $route_string
	

