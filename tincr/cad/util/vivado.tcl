# vivado.tcl 
# Perform general operations on Vivado objects.
#
# The byu_util package contains procs that provide basic functionality for Tcl
# and Vivado.

# Register the package
package provide tincr.cad.util 0.0

package require Tcl 8.5
package require struct 2.1

# TODO All of these should be refactored into the global namespace
namespace eval ::tincr {
	namespace export \
		get_name \
		get_type \
		get_class
}

proc ::tincr::get_name { obj } {
	# Summary:
	# Get the name of a Vivado object as a string

	# Argument Usage:
	# obj : The object you want the name of

	# Return Value:
	# The object's name, as a string

	# Categories: xilinxtclstore, byu, tincr, util
	
	return [get_property NAME $obj]
}

proc ::tincr::get_type { obj } {
	# Summary:
	# Get the name of a Vivado object as a string

	# Argument Usage:
	# obj : The object you want the name of

	# Return Value:
	# The object's name, as a string

	# Categories: xilinxtclstore, byu, tincr, util
	
	switch [get_class $obj] {
		# Logical
		cell {
			return [get_property REF_NAME $obj]
		}
		# Physical
		bel {
			return [get_property TYPE $obj]
		}
		site {
			return [get_property SITE_TYPE $obj]
		}
		tile {
#			return [get_property TYPE $obj]
			return [get_property TILE_TYPE $obj]
		}
		default {
			error "ERROR: $obj not recognized."
		}
	}
	
	return [get_property NAME $obj]
}

proc ::tincr::get_class { obj } {
	# Summary:
	# Get the class of a Vivado object as a string

	# Argument Usage:
	# obj : The object you want the class of

	# Return Value:
	# The object's class, as a string

	# Categories: xilinxtclstore, byu, tincr, util
	
	return [get_property CLASS $obj]
}