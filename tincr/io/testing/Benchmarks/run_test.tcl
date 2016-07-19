#	This procedure tests the "tincr::read_tcp function for all benchmarks in the specified directory.
#	For this function, all benchmarks are assumed to be fully placed and routed. It records the 
#	runtime for each stage of importing, and tests the imported design for correctness.
#	All timing/size statistics are aggregated in the file results.csv (in the same directory as the 
#	benchmarks) where graphs can be generated using excel:
#	TODO: Find a way to automate the graph creation process? 
#
# 	Author Thomas Townsend
proc run_vivado_import_test { directory } {

	if { 0 } {
		set last [string index $directory end]
	
		if {$last == "\\"} {
			set directory [string range $directory 0 end-1]
		}
	}	
	
	set test [::tincr::add_extension [file separator] $directory ]
	
	puts $test
	set a "testing"
	file mkdir "$test$a"
	
	# check to make sure that the command line parameter is a directory
	if {[file isdirectory $directory] == 0} {
		puts "[ERROR] Command line command line parameter does not point to a directory!"
		return 
	}
	
	# get the TINCR checkpoints in the specified directory
	set benchmarks [glob -directory $directory *.tcp]
	
	# if no TINCR checkpoints are found, throw an error and return
	if { [llength $benchmarks] == 0 } {
		puts "[ERROR] No TINCR checkpoints found in specified directory. Cannot run import test."
		return
	}
	
	# create the output .csv file where the results will be stored
	set csv "results.csv"
	set results_outfile "$directory$csv"
	set fp [open $results_outfile w]

	# import each benchmark found in the specified directory 
	# and record the timing and size statistics of the benchmark
	puts $fp "Benchmark,# Cells,# Nets,# Sites,Edif,Link Design,Constraints,Place,Route,Total"
	
	puts "\nRunning Import Tests"
	puts "--------------------"
	
	foreach benchmark $benchmarks {
		puts "Processing $benchmark..."
		puts -nonewline $fp "$benchmark,"
		
		set runtimes [tincr::read_tcp -quiet $benchmark]
		
		# check to make sure that the benchmark imported correctly
		# throw an error if it does not 
		if {[is_import_valid] == 0} {
			puts "[ERROR] Benchmark $benchmark did not import successfully!"
			puts "\tImport this benchmark separately to debug the problem"
			close $fp
			return
		}		
		
		#print timing and size statistics to .csv file
		puts -nonewline $fp "[llength [get_cells -hierarchical -quiet]],"
		puts -nonewline $fp "[llength [get_nets -hierarchical -quiet]],"
		puts -nonewline $fp "[llength [get_sites -filter IS_USED -quiet]],"	
			
		foreach rt $runtimes {
			puts -nonewline $fp "$rt,"
		}
		
		puts $fp ""
		close_design
	}
	
	close $fp
}

#	This function tests to ensure that the design was successfully imported into Vivado.
#	Currently, the definition of success is that there are no un-routed nets, and 
#	and the only unplaced cells are GND and VCC cells. 
#	TODO: update with constraint files? 
#
# 	@author Thomas Townsend
proc is_import_valid { } {

	# check for unrouted nets
	set unrouted_nets [get_nets -hierarchical -filter {ROUTE_STATUS==UNROUTED} -quiet]
	
	if {$unrouted_nets != ""} {
		return 0
	}
	
	# check for unplaced cells that aren't GND or VCC
	set unplaced_cells [get_cells -hierarchical -filter {STATUS==UNPLACED} -quiet]
	
	foreach cell $unplaced_cells {
		set type [get_property REF_NAME $cell]
		if {$type != "GND" && $type != "VCC"} {
			return 0
		}
	}
	
	return 1
}

