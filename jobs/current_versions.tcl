#!/usr/bin/env port-tclsh

package require macports
mportinit

if {[catch {set res [mportlistall]} result]} {
    puts stderr "$::errorInfo"
    error "listing all ports failed: $result"
}

foreach {name dictionary} $res {
    array unset portinfo
    array set portinfo $dictionary
    puts "${name} $portinfo(version)_$portinfo(revision)"
}

mportshutdown
