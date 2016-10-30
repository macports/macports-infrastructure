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
foreach {name array} $ports {

    array unset portinfo
    array set portinfo $array

    set portname [sql_escape $portinfo(name)]
    if {[info exists portinfo(version)]} {
        set portversion [sql_escape $portinfo(version)]
    } else {
        set portversion ""
    }
    set portdir [sql_escape $portinfo(portdir)]
    if {[info exists portinfo(description)]} {
        set description [sql_escape $portinfo(description)]
    } else {
        set description ""
    }
    if {[info exists portinfo(categories)]} {
        set categories $portinfo(categories)
    } else {
        set categories ""
    }
    if {[info exists portinfo(maintainers)]} {
        set maintainers $portinfo(maintainers)
    } else {
        set maintainers ""
    }
    if {[info exists portinfo(variants)]} {
        set variants $portinfo(variants)
    } else {
        set variants ""
    }
    if {[info exists portinfo(depends_fetch)]} {
        set depends_fetch $portinfo(depends_fetch)
    } else {
        set depends_fetch ""
    }
    if {[info exists portinfo(depends_extract)]} {
        set depends_extract $portinfo(depends_extract)
    } else {
        set depends_extract ""
    }
    if {[info exists portinfo(depends_build)]} {
        set depends_build $portinfo(depends_build)
    } else {
        set depends_build ""
    }
    if {[info exists portinfo(depends_lib)]} {
        set depends_lib $portinfo(depends_lib)
    } else {
        set depends_lib ""
    }
    if {[info exists portinfo(depends_run)]} {
        set depends_run $portinfo(depends_run)
    } else {
        set depends_run ""
    }
    if {[info exists portinfo(platforms)]} {
        set platforms $portinfo(platforms)
    } else {
        set platforms ""
    }
    if {[info exists portinfo(license)]} {
        set licenses $portinfo(license)
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

    foreach fetch_dep $depends_fetch {
        set fetch_dep [sql_escape $fetch_dep]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$fetch_dep');"
    }
    
    foreach extract_dep $depends_extract {
        set extract_dep [sql_escape $extract_dep]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$extract_dep');"
    }

    foreach build_dep $depends_build {
        set build_dep [sql_escape $build_dep]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$build_dep');"
    }

    foreach lib $depends_lib {
        set lib [sql_escape $lib]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$lib');"
    }

    foreach run_dep $depends_run {
        set run_dep [sql_escape $run_dep]
        puts $sqlfd "INSERT INTO dependencies VALUES ('$portname', '$run_dep');"
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
