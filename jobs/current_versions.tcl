#! /usr/bin/env port-tclsh

# Generate a list of the current version(s) of all ports, suitable for
# use with delete_old_archives.py. Needs access to a directory
# containing a current PortIndex for each supported platform, as served
# from rsync.macports.org.

if {[llength $argv] < 1} {
    error "usage: current_versions.tcl portindex_dir"
}
set portindex_dir [lindex $argv 0]

set platforms [list 9 powerpc 9 i386]
foreach vers {10 11 12 13 14 15 16 17 18 19} {
    lappend platforms $vers i386
}
foreach vers {20 21 22 23 24 25} {
    lappend platforms $vers arm $vers i386
}

proc lookup {portname osvers arch} {
    global quick_index
    if {![dict exists $quick_index ${osvers},${arch} $portname]} {
        return {}
    }
    global index_fds
    set offset [dict get $quick_index ${osvers},${arch} $portname]
    set fd [dict get $index_fds ${osvers},${arch}]
    seek $fd $offset
    lassign [gets $fd] portname len
    set portinfo [read $fd $len]
    if {![dict exists $portinfo version]} {
        return {}
    }
    if {[dict exists $portinfo revision]} {
        set revision [dict get $portinfo revision]
    } else {
        set revision 0
    }
    return [list $portname [dict get $portinfo version]_$revision]
}

set index_fds [dict create]
set quick_index [dict create]
set all_ports_dict [dict create]

foreach {osvers arch} $platforms {
    set PortIndex_path [file join $portindex_dir PortIndex_darwin_${osvers}_${arch}]/PortIndex
    dict set index_fds ${osvers},${arch} [open $PortIndex_path r]
    set quickfd [open ${PortIndex_path}.quick r]
    set this_quickindex [dict create {*}[read -nonewline $quickfd]]
    close $quickfd
    dict set quick_index ${osvers},${arch} $this_quickindex
    foreach portname [dict keys $this_quickindex] {
        if {![dict exists $all_ports_dict $portname]} {
            dict set all_ports_dict $portname 1
        }
    }
}

set all_ports [dict keys $all_ports_dict]
unset all_ports_dict

foreach portname $all_ports {
    set versions [dict create]
    foreach {osvers arch} $platforms {
        set lookup_result [lookup $portname $osvers $arch]
        if {$lookup_result ne {}} {
            set thisvers [lindex $lookup_result 1]
            if {![dict exists $versions $thisvers]} {
                dict set versions $thisvers 1
                set portname [lindex $lookup_result 0]
            }
        }
    }
    puts "${portname} [dict keys $versions]"
}
