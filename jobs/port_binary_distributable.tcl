#!/usr/bin/env port-tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Check that binaries of a port are distributable by looking at its license
# and the licenses of its dependencies.
#
# Expected format: A {B C} means the license is A plus either B or C.
#
# Exit status:
# 0: distributable
# 1: non-distributable
# 2: error

set MY_VERSION 0.1

source [file join [file dirname [info script]] distributable_lib.tcl]

proc printUsage {} {
    puts "Usage: $::argv0 \[-d dir\] \[-hvV\] port-name \[variants...\]"
    puts "  -d dir  Use directory 'dir' for persistent data storage"
    puts "  -h      This help"
    puts "  -v      verbose output"
    puts "  -V      show version and MacPorts version being used"
    puts ""
    puts "port-name is the name of a port to check"
    puts "variants is the list of variants to enable/disable: +one -two..."
}

set verbose 0
set showVersion 0
set dbdir ""

while {[string index [lindex $::argv 0] 0] eq "-"} {
    switch [string range [lindex $::argv 0] 1 end] {
        d {
            if {[llength $::argv] < 2} {
                printUsage
                exit 2
            }
            set dbdir [lindex $::argv 1]
            set ::argv [lrange $::argv 1 end]
        }
        h {
            printUsage
            exit 0
        }
        v {
             set verbose 1
        }
        V {
            set showVersion 1
        }
        default {
            puts stderr "Unknown option [lindex $::argv 0]"
            printUsage
            exit 2
        }
    }
    set ::argv [lrange $::argv 1 end]
}

package require macports
mportinit

if {$showVersion} {
    puts "Version $MY_VERSION"
    puts "MacPorts version [macports::version]"
    exit 0
}

if {[llength $::argv] == 0} {
    puts stderr "Error: missing port-name"
    printUsage
    exit 2
}
set portName [lindex $::argv 0]
set ::argv [lrange $::argv 1 end]

if {$dbdir ne ""} {
    init_license_db $dbdir
}

array set variantInfo {}
foreach variantSetting $::argv {
    set variant [split_variants $variantSetting]
    foreach {variantName flag} $variant {
        set variantInfo($variantName) $flag
    }
}

set results [check_licenses $portName [array get variantInfo]]
if {$dbdir ne ""} {
    write_license_db $dbdir
}
if {$verbose} {
    puts [lindex $results 1]
}
exit [lindex $results 0]
