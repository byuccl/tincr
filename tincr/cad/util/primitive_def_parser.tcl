package provide tincr.cad.util 0.0

package require Tcl 8.5
package require struct 2.1

namespace eval ::tincr::primitive_def {
    namespace export \
        parse \
        tokenizer
}

namespace eval ::tincr::primitive_def::tokenizer {
    namespace export \
        tokenize \
        has_token \
        next_token \
        peek_token \
        match_token
        
    namespace ensemble create
}

proc ::tincr::primitive_def::parse {filename} {
    upvar #0 ::tincr::primitive_def::connections connections
    set connections [dict create]
    
    tokenizer::tokenize $filename
    
    parse_primitive_def
#    while {[tokenizer::has_token]} {
#        tokenizer::next_token
#    }
    return $connections
}

proc ::tincr::primitive_def::tokenizer::tokenize {filename} {
    set fp [open $filename r]
    set temp [split [read $fp]]
    close $fp
    
    upvar #0 ::tincr::primitive_def::tokenizer::token_ptr token_ptr
    set token_ptr 0
    
    upvar #0 ::tincr::primitive_def::tokenizer::tokens tokens
    set tokens [list]
    foreach token $temp {
        if {$token == ""} continue
        
        set open_paren [string first "(" $token]
        set close_paren [string first ")" $token]
        
        set idx 0
        while {$open_paren != -1 || $close_paren != -1} {
            set next_paren [::tcl::mathfunc::min $open_paren $close_paren]
            if {$open_paren == -1} {
                set next_paren $close_paren
            } elseif {$close_paren == -1} {
                set next_paren $open_paren
            }
            
            if {$next_paren != $idx} {
                lappend tokens [string range $token $idx $next_paren-1]
                
            }
            
            lappend tokens [string range $token $next_paren $next_paren]
            set idx [expr $next_paren+1]
            
            set open_paren [string first "(" $token $idx]
            set close_paren [string first ")" $token $idx]
        }
        
        if {$idx < [string length $token]} {
            lappend tokens [string range $token $idx [string length $token]-1]
        }
    }
}

proc ::tincr::primitive_def::tokenizer::has_token {} {
    upvar #0 ::tincr::primitive_def::tokenizer::token_ptr token_ptr
    upvar #0 ::tincr::primitive_def::tokenizer::tokens tokens
    return [expr $token_ptr < [llength $tokens]]
}

proc ::tincr::primitive_def::tokenizer::next_token {} {
    upvar #0 ::tincr::primitive_def::tokenizer::token_ptr token_ptr
    upvar #0 ::tincr::primitive_def::tokenizer::tokens tokens
    
    set result [lindex $tokens $token_ptr]
    incr token_ptr
    
    return $result
}

proc ::tincr::primitive_def::tokenizer::peek_token {} {
    upvar #0 ::tincr::primitive_def::tokenizer::token_ptr token_ptr
    upvar #0 ::tincr::primitive_def::tokenizer::tokens tokens
    
    return [lindex $tokens $token_ptr]
}

proc ::tincr::primitive_def::tokenizer::match_token {args} {
    set nocase 0
    set pattern ""
    ::tincr::parse_args {} {nocase} {} {pattern} $args
    
    set token [next_token]
    
    if {![string match {*}$args $token]} {
        error "PARSING ERROR: Incorrect token (at ${::tincr::primitive_def::tokenizer::token_ptr}). Expected: \"$pattern\"; Actual: \"$token\""
    }
}

proc ::tincr::primitive_def::parse_primitive_defs {} {
    tokenizer match_token "("
    tokenizer match_token -nocase "primitive_defs"
    
    set num_defs [tokenizer next_token]
    
    while {[tokenizer peek_token] != ")"} {
        # tokenizer match_token "("
        parse_primitive_def
    }
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_primitive_def {} {
    tokenizer match_token "("
    tokenizer match_token -nocase "primitive_def"
    
    set type [tokenizer next_token]
    set num_pins [tokenizer next_token]
    set num_elements [tokenizer next_token]
    
    while {[tokenizer peek_token] != ")"} {
        tokenizer match_token "("
        
        set lookahead [string tolower [tokenizer peek_token]]
        switch $lookahead {
            "element" {
                parse_element $type
            }
            "pin" {
                parse_site_pin
            }
            default {
                error "PARSING ERROR: Lookahead failed. Unrecognized token \"$lookahead\" at ${::tincr::primitive_def::tokenizer::token_ptr}."
            }
        }
    }
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_cfg {} {
    tokenizer match_token -nocase "cfg"
    
    set cfgs [list]
    
    while {[tokenizer peek_token] != ")"} {
        lappend cfgs [tokenizer next_token]
    }
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_conn {primitive_type} {
    tokenizer match_token -nocase "conn"
    
    set left_element [tokenizer next_token]
    set left_pin [tokenizer next_token]
    set dir [tokenizer next_token]
    set right_element [tokenizer next_token]
    set right_pin [tokenizer next_token]
    
    if {$dir == "==>"} {
        upvar #0 ::tincr::primitive_def::connections connections
        dict lappend2 connections $primitive_type $left_element $left_pin $right_element $right_pin
    }
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_site_pin {} {
    tokenizer match_token -nocase "pin"
    
    set internal_wire [tokenizer next_token]
    set external_wire [tokenizer next_token]
    set dir [tokenizer next_token]
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_element_pin {} {
    tokenizer match_token -nocase "pin"
    
    set name [tokenizer next_token]
    set dir [tokenizer next_token]
    
    tokenizer match_token ")"
}

proc ::tincr::primitive_def::parse_element {primitive_type} {
    tokenizer match_token -nocase "element"
    
    set name [tokenizer next_token]
    set num_pins [tokenizer next_token]
    if {[tokenizer peek_token] == "#"} {
        tokenizer match_token "#"
        tokenizer match_token "BEL"
    }
    
    while {[tokenizer peek_token] != ")"} {
        tokenizer match_token "("
        
        set lookahead [string tolower [tokenizer peek_token]]
        switch $lookahead {
            "cfg" {
                parse_cfg
            }
            "conn" {
                parse_conn $primitive_type
            }
            "pin" {
                parse_element_pin
            }
            default {
                error "ERROR: Lookahead failed. Unrecognized token \"$lookahead\""
            }
        }
    }
    
    tokenizer match_token ")"
}
