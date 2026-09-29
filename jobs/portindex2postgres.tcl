#!/usr/bin/env port-tclsh


### Helper functions

# SQL string escaping.
proc sql_escape {str} {
    regsub -all -- {'} $str {''} str
    return $str
}


### main script

# write sources.conf
set fd [open "sources.conf" "w"]
puts $fd "file://[pwd]/ports \[default\]"
close $fd

# write macports.conf
set fd [open "macports.conf" "w"]
puts $fd "sources_conf [pwd]/sources.conf"
close $fd

# export custom configuration
set env(PORTSRC) "[pwd]/macports.conf"

# Load and initialize MacPorts
package require macports 1.0

array set ui_options {ports_verbose yes}
mportinit ui_options

# Open SQL output file
set sqlfd [open "PortIndex.sql" "w"]

# Start transaction
puts $sqlfd "BEGIN;"

# Create schema
puts $sqlfd "CREATE TABLE IF NOT EXISTS log (activity VARCHAR(255), activity_time TIMESTAMP);"
puts $sqlfd "CREATE TABLE IF NOT EXISTS portfiles (name VARCHAR(255) PRIMARY KEY NOT NULL, path VARCHAR(255), version VARCHAR(255),  description TEXT);"
puts $sqlfd "CREATE TABLE IF NOT EXISTS categories (portfile VARCHAR(255), category VARCHAR(255), is_primary INTEGER);"
puts $sqlfd "CREATE TABLE IF NOT EXISTS maintainers (portfile VARCHAR(255), maintainer VARCHAR(255), is_primary INTEGER);"
puts $sqlfd "CREATE TABLE IF NOT EXISTS dependencies (portfile VARCHAR(255), library VARCHAR(255));"
puts $sqlfd "CREATE TABLE IF NOT EXISTS variants (portfile VARCHAR(255), variant VARCHAR(255));"
puts $sqlfd "CREATE TABLE IF NOT EXISTS platforms (portfile VARCHAR(255), platform VARCHAR(255));"
puts $sqlfd "CREATE TABLE IF NOT EXISTS licenses (portfile VARCHAR(255), license VARCHAR(255));"

# Truncate existing data
puts $sqlfd "TRUNCATE portfiles;"
puts $sqlfd "TRUNCATE categories;"
puts $sqlfd "TRUNCATE maintainers;"
puts $sqlfd "TRUNCATE dependencies;"
puts $sqlfd "TRUNCATE variants;"
puts $sqlfd "TRUNCATE platforms;"
puts $sqlfd "TRUNCATE licenses;"

# Get list of all ports
set ports [mportlistall]

# Iterate over each matching port, extracting its information from the
# portinfo array.
foreach {name portinfo} $ports {

    set portname [sql_escape $name]
    if {[dict exists $portinfo version]} {
        set portversion [sql_escape [dict get $portinfo version]]
    } else {
        set portversion ""
    }
    set portdir [sql_escape [dict get $portinfo portdir]]
    if {[dict exists $portinfo description]} {
        set description [sql_escape [dict get $portinfo description]]
    } else {
        set description ""
    }
    if {[dict exists $portinfo categories]} {
        set categories [dict get $portinfo categories]
    } else {
        set categories ""
    }
    if {[dict exists $portinfo maintainers]} {
        set maintainers [dict get $portinfo maintainers]
    } else {
        set maintainers ""
    }
    if {[dict exists $portinfo variants]} {
        set variants [dict get $portinfo variants]
    } else {
        set variants ""
    }
    set alldeps [list]
    foreach deptype {fetch extract patch build lib run} {
        if {[dict exists $portinfo depends_${deptype}]} {
            lappend alldeps {*}[dict get $portinfo depends_${deptype}]
        }
    }
    if {[dict exists $portinfo platforms]} {
        set platforms [dict get $portinfo platforms]
    } else {
        set platforms ""
    }
    if {[dict exists $portinfo license]} {
        set licenses [dict get $portinfo license]
    } else {
        set licenses ""
    }

    puts $sqlfd "INSERT INTO portfiles VALUES ('$portname', '$portdir', '$portversion', '$description');"

    set primary 1
    foreach category $categories {
        set category [sql_escape $category]
        puts $sqlfd "INSERT INTO categories VALUES ('$portname', '$category', $primary);"
        set primary 0
    }
    
    set primary 1
    foreach maintainer $maintainers {
        set maintainer [sql_escape $maintainer]
        puts $sqlfd "INSERT INTO maintainers VALUES ('$portname', '$maintainer', $primary);"
        set primary 0
    }

    foreach dep $alldeps {
        set dep [sql_escape $dep]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$dep');"
    }

    foreach variant $variants {
        set variant [sql_escape $variant]
        puts $sqlfd "INSERT INTO variants VALUES ('$portname', '$variant');"
    }

    foreach platform $platforms {
        set platform [sql_escape $platform]
        puts $sqlfd "INSERT INTO platforms VALUES ('$portname', '$platform');"
    }

    foreach license $licenses {
        set license [sql_escape $license]
        puts $sqlfd "INSERT INTO licenses VALUES ('$portname', '$license');"
    }

}

# Insert timestamp of last update
puts $sqlfd "INSERT INTO log VALUES ('update', NOW());"

# End transaction
puts $sqlfd "COMMIT;"

# Close SQL output file
close $sqlfd

exit 0
