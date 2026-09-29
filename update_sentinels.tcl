foreach file [glob -nocomplain verification/tb/*.sv verification/tb/*.v] {
    set fd [open $file r]
    set content [read $fd]
    close $fd
    
    set new_content [regsub -all "RESULT: PASS" $content "TB_RESULT: PASS"]
    set new_content [regsub -all "RESULT: FAIL" $new_content "TB_RESULT: FAIL"]
    
    if {$new_content ne $content} {
        set fd [open $file w]
        puts -nonewline $fd $new_content
        close $fd
        puts "Updated $file"
    }
}