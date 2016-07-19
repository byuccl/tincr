#	This procedure tests the runtime of the "tincr::write_tcp" function.
#	The timing results are stored in the file results.csv, which can then be opened in 
#	excel where graphs can be generated
# 
#	Parameters: 
#		checkpoint_dir: Directory that contains the Vivado checkpoints to evaluate
#		output_dir: Directory where the TINCR checkpoints will be written to
#
#	Author: Thomas Townsend 
proc run_vivado_export_test { checkpoint_dir output_dir} {

	# check to make sure that the first command line parameter is a directory
	if {[file isdirectory $checkpoint_dir] == 0} {
		puts "[ERROR] Command line command line parameter does not point to a directory!"
		return 
	}
	
	# get the Vivado checkpoints in the specified directory
	set benchmarks [glob -directory $checkpoint_dir *.dcp]
	
	# if no TINCR checkpoints are found, throw an error and return
	if { [llength $benchmarks] == 0 } {
		puts "[ERROR] No Vivado checkpoint files found in specified directory. Cannot run export test."
		return
	}
	
	# create the output .csv file where the results will be stored
	set csv "results.csv"
	set results_outfile "$checkpoint_dir$csv"
	set fp [open $results_outfile w]
  
	# add a file separator and create the output directory if it doesn't already exist
	set output_dir [::tincr::add_extension [file separator] $output_dir]
	
	if {[file isdirectory $output_dir] == 0} {
		file mkdir $output_dir
	}
		
	# run the export test 
	puts $fp "Benchmark,# Cells,# Nets,# Sites,Export Time(s),"
	puts "\nRunning Export Tests"
	puts "--------------------"
	
	foreach benchmark $benchmarks {
		set name [get_benchmark_name $benchmark]

		puts -nonewline $fp "$name,"
		puts "Processing $name.dcp..."
		open_checkpoint -quiet $benchmark
		
		puts -nonewline $fp "[llength [get_cells -quiet]],"
		puts -nonewline $fp "[llength [get_nets -quiet]],"
		puts -nonewline $fp "[llength [get_sites -filter IS_USED -quiet]],"	
				
		set export_time_string [time {tincr::write_tcp "$output_dir$name"}] 
		
		puts $fp "[get_time_in_seconds $export_time_string],"
		close_design -quiet
	}
	
	#file delete -force $testDir	
	close $fp
	puts "Done!"
}

# helper function to parse the benchmark name
proc get_benchmark_name { benchmark } {
	set tmp [lindex [split $benchmark "/"] end]
	return [lindex [split $tmp "."] 0]
}


# helper function used to parse a tcl time string and return the runtime in seconds
proc get_time_in_seconds { tcl_time_string } {
	set time_microseconds [lindex [split $tcl_time_string " "] 0]
	set time_seconds [expr {double($time_microseconds) / double(1000000)} ]
	return $time_seconds 
}