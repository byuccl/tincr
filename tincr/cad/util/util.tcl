# byu_util.tcl 
# Perform basic Tcl and Vivado functions.
#
# The byu_util package contains procs that provide basic functionality for Tcl
# and Vivado.

package provide tincr.cad.util 0.0

package require Tcl 8.5
package require struct 2.1

## @brief All of the Tcl procs provided in the BYU packages are members of the
#  byu namespace.
namespace eval ::tincr {
    namespace export \
        refresh_packages \
        diff_files \
        print \
        print_list \
        parse_options \
        parse_flags_and_options \
        parse_args \
        parse_args2 \
        parse_arguments \
        generate_namespace_export_list \
        binary_search \
        dict_difference \
        count_dict_leaves \
        lequal \
        list_match \
        foreach_element \
        build_list \
        lpop \
        lremove \
        min \
        max \
        minimum_index \
        maximum_index \
        contains_substring \
        ends_with \
        starts_with \
        add_extension \
        is_valid_filename \
        report_runtime \
        average_runtime \
        format_time \
        catch_info \
        compare_objects \
        diff_objects \
        list_properties \
        print_object_properties \
        remove_speedgrade \
        process_handler \
        spawn_vivado_run \
        run_in_temporary_project \
        organize_by \
        print_verbose \
        assert \
        prefix \
        suffix \
        set_tcl_display_limit \
        reset_tcl_display_limit
}

# ================== Files and Other I/O ================== #

proc ::tincr::refresh_packages { } {
    puts "Refreshing all Tincr packages:"
    foreach pkg [lsort [package names]] {
        if {[string first tincr $pkg 0] != -1} {
            puts -nonewline "\tRefreshing $pkg package..."
            if {[catch {package forget $pkg} info]} {
                puts "Problem unloading package \"$pkg\": $info"
            }
            if {[catch {package require $pkg} info]} {
                puts "Problem loading package \"$pkg\": $info"
            }
            puts "DONE"
        }
    }
}

proc ::tincr::diff_files { args } {
    # Summary:
    # Compare two files line-by-line.

    # Argument Usage:
    # [-log <arg> = ""] Output the results to a log file
    # [-log_channel <arg> = ""] Output the results to the specified channel or list of channels
    # [-nocase] Ignore case
    # [-quiet] Suppress the output to stdout
    # [-max_lines <arg> = 200] The maximum number of lines to print in one difference
    # [-max_differences <arg> = 100] The maximum number of separate differences to print
    # filename1 : The first file to compare
    # filename2 : The second file to compare

    # Return Value:
    # The number of differences found. Contiguous groups of differing lines
    # are counted as a single difference. Identical files always return 0.
    # If invalid arguments are provided, an error is thrown.

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # This is modeled after the Unix diff command,
    # though the output may differ from diff in ambiguous cases. Usage:
    # tclapp::byu::tincr::diff_files [OPTION]... FILE1 FILE2

    # valid options
    set nocase 0
    set quiet 0
    set log ""
    set log_channel ""
    # The maximum number of lines to print
    set max_lines 200
    # The maximum number of separate differences to print
    set max_differences 100
    ::tincr::parse_arguments $args filename1 filename2

    # Load files (last two args) and check for newlines at the end of the file
    set fid1 [open $filename1]
    set file1 [split [read $fid1] "\n"]
    close $fid1
    
    if {[lindex $file1 end] == ""} {
        set file1_newline 1
        set file1 [lrange $file1 0 end-1]
    } else {
        set file1_newline 0
    }
    
    set fid2 [open $filename2]
    set file2 [split [read $fid2] "\n"]
    close $fid2
    
    if {[lindex $file2 end] == ""} {
        set file2_newline 1
        set file2 [lrange $file2 0 end-1]
    } else {
        set file2_newline 0
    }
    
    set file1_missing_newline [expr {!$file1_newline && $file2_newline}]
    set file2_missing_newline [expr {$file1_newline && !$file2_newline}]
    
    # Differences format is {f1_start f1_end f2_start f2_end type_specifier}
    # The line numbers are what are PRINTED, not used as indices
    set differences {}
    
    # Apply lowercase option
    if {$nocase} {
        set strings_equal {string equal -nocase}
    } else {
        set strings_equal {string equal}
    }
    
    set f1 0
    set f2 0

    while {$f1 < [llength $file1] || $f2 < [llength $file2]} {
        # Check if only one of the two files hit eof
        if {$f1 == [llength $file1]} {
            lappend differences "$f1 -1 $f2 [expr [llength $file2] - 1] a"
            break
        } elseif {$f2 == [llength $file2]} {
            lappend differences "$f1 [expr [llength $file1] - 1] [expr $f2 - 1] -1 d"
            break
        }
        
        set line1 [lindex $file1 $f1]
        set line2 [lindex $file2 $f2]
        
        # Move on if the lines are the same, or record the difference if not
        if {[{*}$strings_equal $line1 $line2]} {
            incr f1
            incr f2
        } else {
            set f1_resync -1
            set f2_resync -1
            # This n^2 in number of lines. Could hash the lines to speed up lookup 
            for {set f1_find $f1} {$f1_find < [llength $file1] && $f1_resync < 0} {incr f1_find} {
                for {set f2_find $f2} {$f2_find < [llength $file2]} {incr f2_find} {
                    if {[{*}$strings_equal [lindex $file1 $f1_find] [lindex $file2 $f2_find]]} {
                        set f1_resync $f1_find
                        set f2_resync $f2_find
                        break
                    }
                }
            }
            
            # At same position in file1 => Added lines to file2
            # At same position in file2 => Deleted lines in file2
            # Rejoined but at different places => Changed lines
            if {$f1 == $f1_resync} {
                lappend differences "$f1 -1 $f2 [expr $f2_resync - 1] a"
            } elseif {$f2 == $f2_resync} {
                lappend differences "$f1 [expr $f1_resync - 1] [expr $f2 - 1] -1 d"
            } elseif {$f1_resync >= 0} {
                lappend differences "$f1 [expr $f1_resync - 1] $f2 [expr $f2_resync - 1] c"
            } else {
                # Ran to end of file without synchronizing => changed lines ran to eof
                lappend differences "$f1 [expr [llength $file1] - 1] $f2 [expr [llength $file2] - 1] c"
                break
            }
            
            set f1 [expr $f1_resync + 1]
            set f2 [expr $f2_resync + 1]
        }
    }
    
    # Print the results
    # Do not print anything if -quiet is specified
    if {!$quiet || [string length $log] || [string length $log_channel]} {
        # set up the outputs
        set channels {}
        if {!$quiet} {
            lappend channels stdout
        }
        if {[string length $log]} {
            set log [open $log w]
            lappend channels $log
        }
        if {[string length $log_channel]} {
            lappend channels $log_channel
        }
        
        foreach difference [lrange $differences 0 $max_differences\-1] {
            set f1_start [lindex $difference 0]
            set f1_end [lindex $difference 1]
            set f2_start [lindex $difference 2]
            set f2_end [lindex $difference 3]
            set type [lindex $difference 4]
            
            # Print the affected line numbers.
            # Format is <file1_line>[acd]<file2_line> | <file1_start>,<file1_end>[acd]<file2_start>,<file2_end>
            if {$type == "a"} {
                print -nonewline $channels $f1_start
            } else {
                print -nonewline $channels [expr $f1_start + 1]
            }
            if {$f1_end >= 0 && $f1_start != $f1_end} {
                print -nonewline $channels ",[expr $f1_end + 1]"
            }
            print -nonewline $channels $type[expr $f2_start + 1]
            if {$f2_end >= 0 && $f2_start != $f2_end} {
                print -nonewline $channels ",[expr $f2_end + 1]"
            }
            print $channels ""
            
            # Output the line information based on which type of difference this is
            set f1_end [min [expr {$f1_start + $max_lines - 1}] $f1_end]
            set f2_end [min [expr {$f2_start + $max_lines - 1}] $f2_end]
            
            switch $type {
                a {
                    for {set l $f2_start} {$l <= $f2_end} {incr l} {
                        print $channels "> [lindex $file2 $l]"
                    }
                }
                d {
                    for {set l $f1_start} {$l <= $f1_end} {incr l} {
                        print $channels "< [lindex $file1 $l]"
                    }
                }
                c {
                    for {set l $f1_start} {$l <= $f1_end} {incr l} {
                        print $channels "< [lindex $file1 $l]"
                    }
                    # add a note if file ended without a newline
                    set runs_to_eof [expr $f1_end == [llength $file1]-1 && $f2_end == [llength $file2]-1]
                    if {$runs_to_eof && $file1_missing_newline} {
                        print $channels {\ No newline at end of file}
                    }
                    
                    print $channels ---
                    for {set l $f2_start} {$l <= $f2_end} {incr l} {
                        print $channels "> [lindex $file2 $l]"
                    }
                    
                    if {$runs_to_eof && $file2_missing_newline} {
                        print $channels {\ No newline at end of file}
                    }
                }
            }
        }
        
        # Note if there was no newline at the end of the file but lines matched otherwise
        if {($file1_missing_newline || $file2_missing_newline) && [lindex $file1 end] == [lindex $file2 end]} {
            print $channels "[llength $file1]c[llength $file2]"
            print $channels "< [lindex $file1 end]"
            if {$file1_missing_newline} { print $channels {\ No newline at end of file} }
            print $channels ---
            print $channels "> [lindex $file2 end]"
            if {$file2_missing_newline} { print $channels {\ No newline at end of file} }
            lappend differences {}
        }
        
        if {[string length $log]} {close $log}
    }
    
    return [llength $differences]
}

proc ::tincr::print { args } {
    # Summary:
    # Prints the last argument to the specified channels.

    # Argument Usage:
    # [-nonewline] : Do not include a newline character
    # channel : The list of channels to print to - can be a list or separate variables
    # message : The message to print

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # Any number of channels may be provided, including lists of channels.
    # The channel for standard out is "stdout".
    # Usage:
    # ::tincr::print [-nonewline] CHANNEL [CHANNEL]... MESSAGE

    if {[lindex $args 0] == "-nonewline"} {
        set cmd {puts -nonewline}
        set start 1
    } else {
        set cmd puts
        set start 0
    }

    set channels [string map {\{ "" \} ""} [lrange $args $start end-1]]
    foreach channel $channels {
        {*}$cmd $channel [lindex $args end]
    }
}

## Prints a list to specified channel with the specified header
#  @param print_list The list to print
#  @param header Optional header to print before the list
#  @param channel Channel to print the list to. The default channel is stdout
#  @param newline Specifies whether to print a new line between list elements. Default is no.
proc ::tincr::print_list { args } {
    set newline 0
    set channel ""
    set header ""
    ::tincr::parse_args {channel header} {newline} {} {print_list} $args
        
    if ($newline) {
        set cmd puts
    } else {
        set cmd {puts -nonewline}
    }
    
    # if no channel is specified, print to console
    if {$channel == ""} {
        set channel "stdout"
    }
    
    if {$header != ""} {
        {*}$cmd $channel "$header " 
    }
    
    foreach element $print_list {
        {*}$cmd $channel "$element "
    }
    
    puts $channel {}
}

## Sets the tcl standard out display limit. Passing in 0 will disable the tcl
#   display limit completely.
#
# @param limit tcl display limit. default is 500
proc ::tincr::set_tcl_display_limit { limit } {
    set_param tcl.collectionResultDisplayLimit $limit
}

## Resets the tcl display limit to the default of 500
#
proc ::tincr::reset_tcl_display_limit {} {
    set_param tcl.collectionResultDisplayLimit 500
}

# ================== Procedures ================== #

proc ::tincr::parse_options { _args } {
    # Summary:
    # This helper procedure parses arguments passed to a proc in the form
    # -variable_name <value>.

    # Argument Usage:
    # _args : The list of arguments to pars

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The fully realized version of this proc is ::tincr::parse_arguments.
    # This procedure uses upvar to set the
    # values of the variables in calling procedure. The variables must be defined
    # in the calling procedure. For example, if the variable
    # cool_var were set in the calling procedure, the call
    # ::tincr::parse_options -cool_var 42 would set cool_var
    # to the value 42. An error is thrown if an unrecognized variable
    # name is provided.

    if {[llength $_args] % 2} {
        error "ERROR: All options must be assigned a value: -option <value>." 
    }
    
    foreach {_opt _val} $_args {
        if {[string index $_opt 0] != "-"} {
            error "ERROR: All options must begin with \"-\", but \"$_opt\" does not." 
        }
        
        upvar [string range $_opt 1 end] var 
        if {[::info exists var]} {
            set var $_val
        } else {
            error "Unrecognized option \"$_opt\"."
        }
    }
}

proc ::tincr::parse_flags_and_options { _args } {
    # Summary:
    # This procedure is the same as ::tincr::parse_options,
    # except that flags are are accepted.

    # Argument Usage:
    # _args : The list of arguments to parse

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The fully realized version of this proc is ::tincr::parse_arguments.
    # Flag variables must all be set to 0. If an option is the
    # final option or the option following it starts with a dash and the
    # variable's default value is 0, it is assumed to be a flag and is set to 1.

    for {set _i 0} {$_i < [llength $_args]} {incr _i} {
        # check that the option begins with -
        if {[string index [lindex $_args $_i] 0] != "-"} {
            error "ERROR: All options must begin with \"-\", but \"[lindex $_args $_i]\" does not." 
        }
        
        # process the option
        upvar [string range [lindex $_args $_i] 1 end] var
        if {[::info exists var]} {
            # check the next argument to decide if this is a flag or an option
            if {$_i == [expr [llength $_args]-1]
                || ([string index [lindex $_args $_i+1] 0] == "-"
                && [uplevel 1 ::info exists [list [string range [lindex $_args $_i+1] 1 end]]])} {
                    
                # flags must default to 0 or they are interpreted as options
                if {$var == 0} {
                    set var 1
                } else {
                    error "ERROR: No value was provided for the option \"[lindex $_args $_i]\"."
                }
            } else {
                incr _i
                set var [lindex $_args $_i]
            }
        } else {
            error "ERROR: Unrecognised option \"[lindex $_args $_i]\"."
        }
    }
}

# TODO New parse_args that allows any arrangement of flag/options within the function
# TODO Extract flags/options first using an ExtractArgs function (useful with get functions too
proc ::tincr::parse_args { options flags optional required arguments } {
    # Summary:
    # Parses the list "arguments" according to the given lists of argument categories:
    #   1.) options: These are arguments which take the form of -<option> <value>.
    #   2.) flag: Performs a logical not on the value of the argument defined by -<flag>.
    #   3.) optional: Arguments that are not necessarily required.
    #   4.) required: Arguments which are absolutely required.
    # Prints out a usage statement when the values in "arguments" doesn't conform to the given lists of arguments.
    # Optional arguments are populated in the order they appear in the "optional" list
    # Values for arguments in the options, flags, optional, and required lists are stored in variables of the same name in the calling proc. 
    # No need to declare the variable before calling parse_args.
    # To set defaults for each argument, simply set the variable before calling parse_args:
    #   set path "C:\"
    #   parse_args {} {} {path} {} $args

    # Argument Usage:
    # options : A list of option arguments. These take the form of [-<option> <value>] and are not required.
    # flags : A list of flag arguments. These take the form of [-<flag>] and are not required. The same flag can appear multiple times in arguments, and each time it is parsed it toggles its variable's boolean value.
    # optional : 
    # required : 

    # Return Value:
    # The generated usage statement.

    # Categories: xilinxtclstore, byu, tincr, extract

    # Notes:
    # - Optional arguments are populated in order they appear in the list "optional"
    # - This method will create the variables if they haven't been already
    
    # Generate the usage statement
    set usage "USAGE:"
    for {set i 0} {$i < [expr [llength [::info level 1]] - [llength $arguments]]} {incr i} {
        set cmd [lindex [::info level 1] $i]
        append usage " $cmd"
    }
    foreach option $options {
        append usage " \[-" $option " arg\]"
    }
    foreach flag $flags {
        append usage " \[-" $flag "\]"
    }
    foreach opt_arg $optional {
        append usage " \[" $opt_arg "\]"
    }
    foreach req_arg $required {
        append usage " " $req_arg
    }
    
    # If there are fewer than the required number of arguments, throw an error
    if {[llength $arguments] < [llength $required]} {
        error $usage
    } else {
        # Parse required arguments first
        set offset [expr [llength $arguments] - [llength $required]]
        for {set i 0} {$i < [llength $required]} {incr i} {
            upvar [lindex $required $i] var
            set var [lindex $arguments $offset]
            set arguments [lreplace $arguments $offset $offset]
        }
        
        # Parse options, flags, and optional arguments, not necessarily in that order
        for {set i 0} {$i < [llength $arguments]} {incr i} {
            set argument [lindex $arguments $i]
            
            # If the current arg begins with a '-', it's either an option or flag
            if {[string index [lindex $arguments $i] 0] == "-"} {
                set argument [string range $argument 1 end]
                
                # Modification to allow unique partial matching
                append argument "*"
                set match [lsearch -all -inline -glob [concat $options $flags] $argument]
                if {[llength $match] != 1} {
                    puts $usage
                    error "ERROR: The argument \"-[string range $argument 0 end-1]\" is ambiguous and may refer to any of the following switches: $match"
                } else {
                    set argument [lindex $match 0]
                }
                
                # If it's an option...
                if {[lsearch $options $argument] != -1} {
                    upvar $argument var
                    # Parse the next arg as the option's value
                    incr i
                    if {$i < [llength $arguments]} {
                        set var [lindex $arguments $i]
                    # If there are no more args, throw an error
                    } else {
                        error $usage
                    }
                # If it's a flag...
                } elseif {[lsearch $flags $argument] != -1} {
                    upvar $argument var
                    # Create the variable and set it to 0 if it doesn't already exist
                    if {[expr ![uplevel 1 ::info exists $argument]]} {
                        set var 0
                    }
                    # Not the flag's value
                    set var [expr !$var]
                # Otherwise, throw an error
                } else {
                    error $usage
                }
            # Otherwise it is an optional argument
            } else {
                # If there is still an optional argument left to populate,
                if {[llength $optional] > 0} {
                    # set it to the current arg,
                    upvar [lindex $optional 0] var
                    set var $argument
                    # and remove it from the list
                    set optional [lreplace $optional 0 0]
                # Otherwise throw an error
                } else {
                    error $usage
                }
            }
        }
    }
    
    return $usage
}

proc ::tincr::extract_flag {flag var_name args_name} {
    # Check if flag has a leading '-'
    set i 0
    for {} {$i < [string length $flag]} {incr i} {
        if {[string index $flag $i] != "-"} break
    }
    set flag "-[string range $flag $i end]"
    puts $flag
    
    upvar $var_name var
    upvar $args_name args
    
    for {set i [expr [llength $args] - 1]} {$i >= 0} {incr i -1} {
        set arg [lindex $args $i]
        if {$arg == $flag} {
            set args [lreplace $args $i $i]
            
            if {![info exists var]} {
                set var 0
            }
            
            set var [expr !$var]
        }
    }
}

proc ::tincr::parse_args2 {flags options statements args} {
    set usage "USAGE:"
    for {set i 0} {$i < [expr [llength [::info level 1]] - [llength $arguments]]} {incr i} {
        set cmd [lindex [::info level 1] $i]
        append usage " $cmd"
    }
    foreach flag $flags {
        append usage " \[-" $flag "\]"
    }
    foreach option $options {
        append usage " \[-" $option " arg\]"
    }
    foreach opt_arg $optional {
        append usage " \[" $opt_arg "\]"
    }
    foreach req_arg $required {
        append usage " " $req_arg
    }
    
    # If there are fewer than the required number of arguments, throw an error
    if {[llength $arguments] < [llength $required]} {
        error $usage
    } else {
        # Parse required arguments first
        set offset [expr [llength $arguments] - [llength $required]]
        for {set i 0} {$i < [llength $required]} {incr i} {
            upvar [lindex $required $i] var
            set var [lindex $arguments $offset]
            set arguments [lreplace $arguments $offset $offset]
        }
        
        # Parse options, flags, and optional arguments, not necessarily in that order
        for {set i 0} {$i < [llength $arguments]} {incr i} {
            set argument [lindex $arguments $i]
            
            # If the current arg begins with a '-', it's either an option or flag
            if {[string index [lindex $arguments $i] 0] == "-"} {
                set argument [string range $argument 1 end]
                
                # Modification to allow unique partial matching
                append argument "*"
                set match [lsearch -all -inline -glob [concat $options $flags] $argument]
                if {[llength $match] != 1} {
                    puts $usage
                    error "ERROR: The argument \"-[string range $argument 0 end-1]\" is ambiguous and may refer to any of the following switches: $match"
                } else {
                    set argument [lindex $match 0]
                }
                
                # If it's an option...
                if {[lsearch $options $argument] != -1} {
                    upvar $argument var
                    # Parse the next arg as the option's value
                    incr i
                    if {$i < [llength $arguments]} {
                        set var [lindex $arguments $i]
                    # If there are no more args, throw an error
                    } else {
                        error $usage
                    }
                # If it's a flag...
                } elseif {[lsearch $flags $argument] != -1} {
                    upvar $argument var
                    # Create the variable and set it to 0 if it doesn't already exist
                    if {[expr ![uplevel 1 ::info exists $argument]]} {
                        set var 0
                    }
                    # Not the flag's value
                    set var [expr !$var]
                # Otherwise, throw an error
                } else {
                    error $usage
                }
            # Otherwise it is an optional argument
            } else {
                # If there is still an optional argument left to populate,
                if {[llength $optional] > 0} {
                    # set it to the current arg,
                    upvar [lindex $optional 0] var
                    set var $argument
                    # and remove it from the list
                    set optional [lreplace $optional 0 0]
                # Otherwise throw an error
                } else {
                    error $usage
                }
            }
        }
    }
    
    return $usage
}

proc ::tincr::parse_arguments { provided_args args } {
    # Summary:
    # Parse the arguments passed to a function, including optional arguments
    # and positional arguments.

    # Argument Usage:
    # provided_args : A list of the arguments provided to the calling proc ($args)
    # args : The names of the positional arguments in order

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # This procedure can parse arbitrarily ordered -flags and -options <arg>
    # followed by required positional arguments. For example:
    # ::proc_name -flag1 -option1 val1 -flag2 positional1 positional2
    # The calling proc must have default values set for all of the possible flags
    # and options. Flags must have the default value 0. The name of positional 
    # arguments are listed following the provided_args list. Positional arguments
    # do not need to have defaults in the calling function set. The variables will
    # be set in the calling function using uplevel.
    # Note: It easy to trick this proc into treating a flag like an option.

    if {[llength $provided_args] < [llength $args]} {
        error "ERROR: No value was provided for [lindex $args [llength $provided_args]]."
    }

    # divide the provided arguments into options and positional parameters
    set positional [lrange $provided_args [llength $provided_args]-[llength $args] [llength $provided_args]]
    set options [lrange $provided_args 0 end-[llength $args]]
    
    # parse the options
    for {set i 0} {$i < [llength $options]} {incr i} {
        # check that the option begins with -
        if {[string index [lindex $options $i] 0] != "-"} {
            error "ERROR: All options must begin with \"-\", but \"[lindex $options $i]\" does not." 
        }
        
        # process the options
        upvar [string range [lindex $options $i] 1 end] var
        if {[::info exists var]} {        
            # check the next argument to decide if this is a flag or an option
            if {$i == [expr [llength $options]-1]
                || ([string index [lindex $options $i+1] 0] == "-"
                && [uplevel 1 ::info exists [list [string range [lindex $options $i+1] 1 end]]])} {
                
                # flags must default to 0 or they are interpreted as options
                if {$var == 0} {
                    set var 1
                } else {
                    error "ERROR: No value was provided for the option \"[lindex $options $i]\"."
                }
            } else {
                incr i
                set var [lindex $options $i]
            }
        } else {
            error "ERROR: Unrecognised option \"[lindex $options $i]\"."
        }
    }
    
    # parse the positional arguments
    # it is essential to use upvar instead of uplevel to preserve 1st-class Tcl objects
    foreach var_name $args value $positional {
        upvar $var_name var
        set var $value
    }
}

proc ::tincr::generate_namespace_export_list { args } {
    # Summary:
    # Generate a string containing all of the names of the procs in the
    # specified Tcl files for use with the namespace export command.

    # Argument Usage:
    # [-endline = " \\\n"] : Optional. How to end namespace export list entries
    # [-startline = "\t\t"] : Optional. How to begin namespace export list entries
    # source_files : 

    # Return Value:
    # A string containing all of the names of the procs in the specified files

    # Categories: xilinxtclstore, byu, tincr, util

    set endline " \\\n"
    set startline "\t\t"
    set regexp {(?:^|\n[\s]*)proc\s+(?:::)?(?:[^:\s]+::)*([^:\s]+)\s+\{}
    ::tincr::parse_arguments $args source_files
    
    set result {}
    
    foreach src_file [string map {\\ /} $source_files] {
        if {[llength $source_files] > 1} {
            append result "\n===[file tail $src_file]===\n"
        }
        set fid [open $src_file]
        set file [read $fid]
        close $fid
        
        foreach proc_name [dict values [regexp -all -inline $regexp $file]] {
            append result $startline$proc_name$endline
        }
        set result [string range $result 0 end-[string length $endline]]
    }
    return $result
}

#

## Asserts that the specified condition is true if assertions are enabled. 
#  Example Usage: assert {$temperature < 100} "Temperature is too high" 
#  @param condition The condition to check
#  @param message Optional message to print if the assertion fails
proc ::tincr::assert {condition {message "Assertion failed"}} {
    if {$::tincr::enable_assertions} {
        if {![uplevel 1 expr $condition]} {
            return -code error "$message: $condition"
        }
    }
}

# ================== Lists and Dictionaries ================== #

proc ::tincr::binary_search { list search } {
    # Summary:
    # Perform a binary search on a list.

    # Argument Usage:
    # list : The list to search
    # search : The text for which to search

    # Return Value:
    # The index of the item if it is found, or -1 if it is not

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The list MUST be sorted for this proc to work.
    # This is significantly faster than lsearch for very large lists, but cannot
    # use patterns. The operation struct::set contains is better
    # than this for checking for set membership.

    set first 0
    set last [expr [llength $list] - 1]
    set cur_idx [expr $last / 2]
    while {$first < $last} {
        set cur_val [lindex $list $cur_idx]
        if {$search < $cur_val} {
            set last [expr $cur_idx - 1]
            set cur_idx [expr ($first + $cur_idx) / 2]
        } elseif {$search > $cur_val} {
            set first [expr $cur_idx + 1]
            set cur_idx [expr ($last + $cur_idx) / 2]
        } else {
            return $cur_idx
        }
    }

    if {[lindex $list $first] == $search} {
        return $first 
    } else {
        return -1
    }
}

proc ::tincr::dict_difference { dict1 dict2 {nesting_level 0} } {
    # Summary:
    # Return a dictionary object that contains the key-value pairs in dict1 that
    # are not in dict2.

    # Argument Usage:
    # dict1 : The dict from which to subtract dict2.
    # dict2 : The dict to subtract from dict1.
    # [nesting_level = 0] : Set how many levels the dictionaries are nested. A nesting level of 1 means that the values for the dictionaries' keys are themselves dictionaries. For example, the following dict has one level of nesting:  {key1 {nested_key1 value nested_key2 value} key2 {nested_key1 value}}  The default nesting level is 0, so all values are treated as lists.  For dictionaries that are nested "all the way down" (whatever that means), set the nesting level to a very large value. Note: a list with an even number of elements is indistinguishable from a dictionary, so it is important to set the nesting level correctly.

    # Return Value:
    # A Tcl dict object containing the key-value pairs in dict1 but not 
    # in dict2.

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # Leaf nodes are treated as lists. Handles nested
    # dictionaries if nesting_level is specified.

    set difference {}
    
    dict for {key val1} $dict1 {
        if {[dict exists $dict2 $key]} {
            set val2 [dict get $dict2 $key]
            if {$val1 != $val2} {
                # Check if this item looks like a nested dict for both (even # elements)
                if {$nesting_level > 0 && [llength $val1] % 2 == 0 && [llength $val2] % 2 == 0} {                    
                    set nested_difference [dict_difference $val1 $val2 [expr $nesting_level - 1]]
                } else {
                    set nested_difference [::struct::set difference $val1 $val2]
                }
                
                # Only set if things in dict1 are not in dict2 -- no empty nested lists/dicts
                if {[llength $nested_difference]} {
                    dict set difference $key $nested_difference
                }
            }
        } else {
            dict set difference $key $val1
        }
    }
    
    return $difference
}

proc ::tincr::count_dict_leaves { dict nesting_levels {count_as ""} } {
    # Summary:
    # Count the number of leaf values in a dictionary.

    # Argument Usage:
    # dict : The dictionary
    # nesting_levels : How many levels of dictionaries dict contains. Set this to 0 if dict does not contain nested dictionaries.
    # [count_as = ""]: Optional. If the the leaf values are lists, set this to -lists to count each element of the lists separately. Otherwise, the list is counted as a single leaf value.

    # Return Value:
    # The number of dictionary leaf items

    # Categories: xilinxtclstore, byu, tincr, util

    set count 0
    
    if {![string is integer $nesting_levels] || $nesting_levels < 0} {
        error "ERROR: The nesting level \"[string range $nesting_levels 0 20]\" must be a positive integer."
    }
    
    foreach value [dict values $dict] {
        if {$nesting_levels > 0 && [llength $value] % 2 == 0} {
            incr count [count_dict_leaves $value [expr {$nesting_levels - 1}] $count_as]
        } elseif {[string range $count_as 0 1] == "-l"} {
            incr count [llength $value]
        } else {
            incr count
        }
    }
    
    return $count
}
    
proc ::tincr::lequal { l1 l2 } {
    # Summary:
    # Determine whether two lists contain the same elements, regardless of order.

    # Argument Usage:
    # l1 : The first list
    # l2 : The second list

    # Return Value:
    # True (1) if the lists contain the same elements, false (0) if they do not

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The normal Tcl list comparison ($list1 == $list2) takes into
    # account the order of the elements. This could also be done with
    # ::struct::set.

    if {[llength $l1] != [llength $l2]} {
        return 0
    }

    return [expr {[lsort $l2] == [lsort $l1]}]
}

proc ::tincr::list_match { search values } {
    # Summary:
    # Perform a string match on each element in a list.

    # Argument Usage:
    # search : The string match-style search string
    # values : The list through which to search.

    # Return Value:
    # A list containing the elements of the values list that matched. 

    # Categories: xilinxtclstore, byu, tincr, util

    set new_list {}
    foreach val $values {
        if {[string match $search $val]} {
            lappend new_list $val
        }
    }
    return $new_list
}

proc ::tincr::foreach_element { cmd list } {
    # Summary:
    # Perform a command on each element in a list and return a list of the
    # results.

    # Argument Usage:
    # cmd : The command to perform on each element in the list. Use the Tcl variable element to refer to each list item. For example, tclapp::byu::tincr::foreach_element {get_tiles -of_objects $element} [get_sites SLICE_X0Y10*]  will get the tiles of slices SLICE_X0Y100 to SLICE_X0Y109.
    # list : The list on which to perform the command.

    # Return Value:
    # A list containing the results of the commands

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # This could be used, for example, to get all of the bels of a list
    # of pins.

    set results {}
    foreach element $list {
        lappend results [eval $cmd]
    }
    
    return $results
}

proc ::tincr::build_list { args } {
    # Summary:
    # Create a list that starts at -start, increments by
    # -incr, and either counts up to -end exclusive or
    # contains -total elements.

    # Argument Usage:
    # [-start = 0] : The starting value
    # [-end = 1] : The ending value
    # [-incr = 0] : The increment between values
    # [-total = ""] : The total number of elements to contain. This overrides -end.

    # Return Value:
    # The generated list

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The -total option overrides the -end option.

    set start 0
    set end 1
    set incr 1
    set total ""
    ::tincr::parse_options $args
    
    if {$total != ""} {
        set condition "\[llength \$list\] < $total"
    } elseif {$end > $start} {        
        set condition "\$i < \$end"
    } elseif {$end < $start} {
        set condition "\$i > \$end"
    } else {
        set condition "\$i == \$end"
    }
    
    set list {}
    for {set i $start} {[expr $condition]} {set i [expr {$i + $incr}]} {
        lappend list $i
    }
    
    return $list
}

proc ::tincr::lpop { varName } {
    # Summary:
    # Pops the last item off of a list.

    # Argument Usage:
    # varName : The name of the list variable

    # Return Value:
    # The list with the last value removed

    # Categories: xilinxtclstore, byu, tincr, util

    upvar 1 $varName list_var
    return [set list_var [lrange $list_var 0 end-1]]
}

proc ::tincr::lremove { varName index } {
    # Summary:
    # Remove the specified item from the list.

    # Argument Usage:
    # varName : The name of the list variable to remove an item from
    # index : The index of the item to remove

    # Return Value:
    # The list with the item removed from it

    # Categories: xilinxtclstore, byu, tincr, util

    upvar 1 $varName list_var
    return [set list_var [concat [lrange $list_var 0 $index-1] [lrange $list_var $index+1 end]]]
}

proc ::tincr::min { args } {
    # Summary:
    # Returns the least of the given arguments.

    # Argument Usage:
    # args : Any number of arguments

    # Return Value:
    # The minimum of the provided arguments

    # Categories: xilinxtclstore, byu, tincr, util

    set minimum [lindex $args 0]
    for {set i 1} {$i < [llength $args]} {incr i} {
        if {[lindex $args $i] < $minimum} {
            set minimum [lindex $args $i]
        }
    }
    
    return $minimum
}

proc ::tincr::max { args } {
    # Summary:
    # Returns the greatest of the given arguments.

    # Argument Usage:
    # args : Any number of arguments

    # Return Value:
    # The maximum of the provided arguments

    # Categories: xilinxtclstore, byu, tincr, util

    set maximum [lindex $args 0]
    for {set i 1} {$i < [llength $args]} {incr i} {
        if {[lindex $args $i] > $maximum} {
            set maximum [lindex $args $i]
        }
    }
    
    return $maximum
}

proc ::tincr::minimum_index { list } {
    # Summary:
    # Returns the index of the least item in the given list.

    # Argument Usage:
    # list : A list

    # Return Value:
    # The index of the least item in the given list

    # Categories: xilinxtclstore, byu, tincr, util

    set mindex 0
    for {set i 1} {$i < [llength $list]} {incr i} {
        if {[lindex $list $i] < [lindex $list $mindex]} {
            set mindex $i
        }
    }
    
    return $mindex
}

proc ::tincr::maximum_index { list } {
    # Summary:
    # Returns the index of the greatest item in the given list.

    # Argument Usage:
    # list : A list

    # Return Value:
    # The index of the greatest item in the given list

    # Categories: xilinxtclstore, byu, tincr, util

    set maxindex 0
    for {set i 1} {$i < [llength $list]} {incr i} {
        if {[lindex $list $i] > [lindex $list $maxindex]} {
            set maxindex $i
        }
    }
    
    return $maxindex
}

# ================== Strings ================== #

proc ::tincr::contains_substring {string substring} {
    # Summary:
    # Returns true if string contains substring.

    # Argument Usage:
    # string : The string to search in
    # substring : The string to search for in the other string

    # Return Value:
    # True (1) if the string contains the substring, false (0) if it does not

    # Categories: xilinxtclstore, byu, tincr, util

    return [regexp "^.*${substring}.*\$" $string]
}

proc ::tincr::ends_with {string1 string2} {
    # Summary:
    # Returns true if string1 ends with string2.

    # Argument Usage:
    # string1 : The string to check
    # string2 : The suffix to check for

    # Return Value:
    # True (1) if the string ends with the other string, false (0) if it does not

    # Categories: xilinxtclstore, byu, tincr, util

    return [regexp "^.*${string2}\$" $string1]
}

proc ::tincr::starts_with {string1 string2} {
    # Summary:
    # Returns true if string1 starts with string2.

    # Argument Usage:
    # string1 : The string to check
    # string2 : The suffix to check for

    # Return Value:
    # True (1) if the string starts with the other string, false (0) if it does not

    # Categories: xilinxtclstore, byu, tincr, util

    return [regexp "^${string2}.*\$" $string1]
}

proc ::tincr::is_valid_filename { filename } {
    # Summary:
    # Returns true if filename is a valid file path and name.

    # Argument Usage:
    # filename : The file name to test

    # Return Value:
    # True (1) if the string appears to be a valid file name, false (0) if it does not

    # Categories: xilinxtclstore, byu, tincr, util

    return [regexp {^[^\?\*\"<>]+$} $filename]
}

proc ::tincr::add_extension { args } {
    ::tincr::parse_args {} {} {} {extension filename} $args
    
    if {![ends_with [string tolower $filename] $extension]} {
        set filename "${filename}${extension}"
    }
    
    return $filename
}

## Splits the <code>string</code> by <code>token</code>, and returns the first element in the list.
#  Helper function used to get the type of Vivado elements. For example, the call
#  <code>prefix "I/am/a/test" "/"</code> will return the string "I."
#
# @param string The string to split 
# @param token The token to split the string on
proc ::tincr::prefix { string token } {
    return [lindex [split $string $token] 0]
}

## Splits the <code>string</code> by <code>token</code>, and returns the last element in the list.
#  Helper function used to get the relative name of Vivado elements. For example, the call
#  <code>suffix "I/am/a/test" "/"</code> will return the string "test."
#
# @param string The string to split 
# @param token The token to split the string on
proc ::tincr::suffix { string token } {
    return [lindex [split $string $token] end]
}

## Format a string so that it is valid XML.
# This replaces illegal characters with their proper entity references. This 
# function is implemented as an alias of a string map function. 
interp alias {} ::tincr::format_xml {} string map {& {&amp;} < {&lt;} > {&gt;} ' {&apos;} \" {&quot;} }

# ================== Timing ================== #

proc ::tincr::report_runtime { cmd {format us} } {
    # Summary:
    # Report the runtime of a command.

    # Argument Usage:
    # cmd : The command to execute and time as a single string.
    # [format = us]: An optional output time format specifier. The valid values are h for hours, m for minutes, s for seconds, ms for milliseconds, us for microseconds, or the combination hms.

    # Return Value:
    # The amount of time required to run the specified command. The time
    # is formatted according to the optional format string, with 
    # microseconds as the default.

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # See also ::tincr::average_runtime and ::tincr::format_time.

    set start_time [clock clicks -microseconds]
    uplevel 1 $cmd
    set end_time [clock clicks -microseconds]
    
    set result [::tincr::format_time [expr $end_time - $start_time] $format]
    
    return $result
}

proc ::tincr::average_runtime { args } {
    # Summary:
    # Report the average runtime of a command over several runs.

    # Argument Usage:
    # [-runs <arg> = 10] : The number of times to execute the command.
    # [-format <arg> = us] : An optional output time format specifier. The valid values are h for hours, m for minutes, s for seconds, ms for milliseconds, us for microseconds, or the combination hms.
    # cmd : The command to execute and time as a single string (enclosed with { } or " " as needed)

    # Return Value:
    # The average amount of time required to run the specified command over
    # the specified number of runs.

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # See also ::tincr::report_runtime and ::tincr::format_time.

    set format us
    set runs 10
    ::tincr::parse_arguments $args cmd
    
    set total 0
    for {set i 0} {$i < $runs} {incr i} {
        set start_time [clock clicks -microseconds]
        uplevel 1 $cmd
        set end_time [clock clicks -microseconds]
        incr total [expr {$end_time - $start_time}]
    }

    return [::tincr::format_time [expr {wide(double($total)/$runs)}] $format]
}

proc ::tincr::format_time { value {format us} } {
    # Summary:
    # Convert a time in microseconds to various formats.

    # Argument Usage:
    # value : The time to convert. This must be an integer number of microseconds.
    # [format = us] : The format into which to convert the time. The valid values are  h for hours, m for minutes, s for seconds, ms for milliseconds, us for microseconds, or the combination hms for hours:minutes:seconds.

    # Return Value:
    # The formatted time

    # Categories: xilinxtclstore, byu, tincr, util
    
    set result $value
    switch $format {
        h {
            set result [format "%f" [expr double($value)/3600000000]]
        }
        m {
            set result [format "%f" [expr double($value)/60000000]]
        }
        s {
            set result [format "%f" [expr double($value)/1000000]]
        }
        ms {
            set result [format "%f" [expr double($value)/1000]]
        }
        us {
        }
        hms {
            set h [expr $value/3600000000]
            set result [expr $value - ($h*3600000000)]
            set m [expr $result/60000000]
            set result [expr $result - ($m*60000000)]
            set s [expr double($result)/1000000]

            set result [format "%02d:%02d:%06.3f" $h $m $s]
        }
    }
    
    return $result
}

# ================== Other Functions ================== #

proc ::tincr::catch_info { cmd } {
    # Summary:
    # Catch any errors for the given command and print the error information.

    # Argument Usage:
    # cmd : The command to execute

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    if {[catch "uplevel 1 $cmd" msg info]} {
        puts [dict get $info -errorinfo]
    }
}

## Imports all commands currently in the ::byu namespace into the global 
#  namespace. This is simply an alias of the command
#  namespace import ::tincr::*
interp alias {} ::tincr::import_all {} namespace import ::tincr::*

proc ::tincr::print_verbose { message {newline 1} } {
    # Summary: 
    # Prints a message to the console if the global variable ::tincr::verbose has been enabled
    
    # Argument Usage:
    # message : Message to print to the screen formatted as a string
    # [newline 0] : Optional newline specifier. Set this to 0 if you don't want a newline printed
 
    # Return Value: none
    
    # Categories: xilinxtclstore, byu, tincr, util
    
    if {$::tincr::verbose} {
        puts -nonewline $message
        if {$newline} {
            puts {}
        }
    }
}

# ================== Basic Vivado Functions ================== #

proc ::tincr::compare_objects { obj1 obj2 } {
    # Summary:
    # Compare two Vivado objects.

    # Argument Usage:
    # obj1 : The first object to compare
    # obj2 : The second object to compare

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # The values of the properties common to the two 
    # objects are listed. See also ::tincr::diff_objects.

    set prop1 [list_property $obj1]
    set prop2 [list_property $obj2]
    set properties [list]
    
    foreach property $prop1 {
        if {[lsearch $prop2 $property] != -1} {
            lappend properties $property
        }
    }
    
    foreach property $properties {
        puts "${property}: [get_property $property $obj1]"
        puts "${property}: [get_property $property $obj2]"
    }
}

proc ::tincr::diff_objects { obj1 obj2 } {
    # Summary:
    # Perform a diff between two Vivado objects.

    # Argument Usage:
    # obj1 : The first object to compare
    # obj2 : The second object to compare

    # Return Value:
    # The number of differences between obj1 and obj2, including the 
    # number of properties that one object has but the other does not.

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # Lists the only properties that differ between obj1 and obj2.
    # The objects may be of any two types.
    # See also ::tincr::compare_objects.

    set prop1 [list_property $obj1]
    set prop2 [list_property $obj2]

    if {$prop1 != $prop2} {
        puts "Note: $obj1 and $obj2 have different sets of properties."
    }
    
    set prop_diffs 0
    foreach property $prop1 {
        if {[lsearch $prop2 $property] != -1} {
            lappend properties $property
        } else {
            incr prop_diffs
        }
    }
    
    if {[llength $prop2] > [llength $prop1]} {
        incr prop_diffs [expr {[llength $prop2] - [llength $prop1]}]
    }
    
    set diffs 0
    foreach property $properties {
        set prop1 [get_property $property $obj1]
        set prop2 [get_property $property $obj2]
        if { $prop1 != $prop2 } {
            puts $property
            puts "\t$obj1: $prop1"
            puts "\t$obj2: $prop2"
            incr diffs
        }
    }
    return [expr {$diffs + $prop_diffs}]
}

proc ::tincr::list_properties { objects {property_regex *} } {
    # Summary:
    # List all of the properties of the specified objects.

    # Argument Usage:
    # objects : The list of objects that will have their properties printed.
    # [property_regex = *] : An optional regular expression to limit which properties will be printed.

    # Return Value:

    # Categories: xilinxtclstore, byu, tincr, util

    # Notes:
    # Calls to get_property sometimes return more information than 
    # calls to report_property.

    foreach object $objects {
        puts "$object"
        foreach prop [list_property -verbose $object -regexp $property_regex] {
            puts "$prop: [get_property $prop $object]"
        }
        puts ""
    }
}

proc ::tincr::print_object_properties { obj } {
    # Summary:
    # Get a string listing an object's properties as an XML-style attributes list.

    # Argument Usage:
    # obj : The object to examine

    # Return Value:
    # A string listing the object's properties as an XML-style attributes list

    # Categories: xilinxtclstore, byu, tincr, util

    set result ""
    
    foreach property [list_property $obj] {
        set attribute "${property}=\"[format_xml [get_property $property $obj]]\" "
        append result $attribute
    }
    
    return [string trimright $result]
}

## Removes the speedgrade on the specified part
#
# @param partname Full name of the part
# @return The partname with the speedgrade removed
proc ::tincr::remove_speedgrade { partname } {
    set partname_no_speedgrade ""
    regexp {^(x[a-z0-9]+(?:-[a-z0-9]+)?)-.+} $partname -> partname_no_speedgrade
    if {$partname_no_speedgrade == ""} {
        set partname_no_speedgrade $partname
    }
    return $partname_no_speedgrade
}

############## MULTI-PROCESS FUNCTIONS ######################

proc ::tincr::process_handler { chan } {
    upvar #0 _TINCR_XDLRC_PROCESS_COUNT pCount
    
    if {[eof $chan]} {
        close $chan;
        incr pCount -1;
#    } elseif {[gets $chan line] != -1} {
#        HACK: DO NOT DELETE THIS ELSEIF OR VIVADO WILL HANG
#        puts $line
    }
}

proc ::tincr::spawn_vivado_run { script } {
    upvar #0 _TINCR_XDLRC_PROCESS_COUNT pCount
    
    set cmd [concat "vivado -mode tcl -source" $script]
#    lappend args [split $script]
    set p [open |$cmd]
    fconfigure $p -blocking 0
    fileevent $p readable [list ::tincr::process_handler $p]
    incr pCount 1
    
    return $p
}

proc ::tincr::run_in_temporary_project { args } {
    set part [lindex [get_parts] 0]
    if {[current_design -quiet] != ""} {
        set part [get_property PART [current_design]]
    }
    
    set max -1
    set name ".Tincr/tmp/prj"
    foreach project [get_projects -quiet -filter NAME=~"${name}*"] {
        if {[regexp "^${name}(\[0-9\]+)\$" [::tincr::get_name $project] matched num]} {
            if {$num > $max} {
                set max $num
            }
        }
    }
    incr max
    set name "${name}${max}"
    ::tincr::parse_args {part name} {} {} {body} $args
    
    set original_project [current_project -quiet]
    
    # set up a temporary sandbox project (which unfortunately saves a .xpr)
    create_project -force $name
    current_project $name
    
    link_design -quiet -part $part -name "${name}_DESIGN"
    
    uplevel 1 $body

    # Close the temporary design and delete the project files
    close_project
    file delete -force "$name.xpr"
    file delete -force "$name.data"
    file delete -force "$name.cache"
    
    current_project -quiet $original_project
}

proc ::tincr::organize_by {elements {property NAME}} {
    set result [dict create]
    
    foreach element $elements {
        dict lappend result [get_property $property $element] $element
    }
    
    return $result
}
