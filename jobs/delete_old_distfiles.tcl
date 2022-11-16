#!/usr/bin/env port-tclsh

# Find all distfiles that exist under distfiles_root and are not needed by
# the current version of any port or by a version existing as a package
# under packages_root.

set start_time [clock seconds]

if {[llength $argv] == 4 && [lindex $argv 0] eq "-k"} {
    set keepfile [lindex $argv 1]
    set argv [lrange $argv 2 end]
}
if {[llength $argv] != 2} {
    puts "Usage: $argv0 [-k keepfile] distfiles_root packages_root"
    exit 1
}
set distfiles_root [lindex $argv 0]
set packages_root [lindex $argv 1]
set archive_type tbz2
if {[info exists env(TMPDIR)]} {
    set tmpdir $env(TMPDIR)
} else {
    set tmpdir /tmp
}
set workdir [file normalize [pwd]]

proc get_variants {portinfovar} {
    upvar $portinfovar portinfo
    if {![info exists portinfo(vinfo)]} {
        return {}
    }
    set variants [list]
    array set vinfo $portinfo(vinfo)
    foreach v [array names vinfo] {
        array unset variant
        array set variant $vinfo($v)
        if {![info exists variant(is_default)] || $variant(is_default) ne "+"} {
            lappend variants $v
        }
    }
    return $variants
}

package require macports
mportinit

set platforms [list 8 powerpc 8 i386 9 powerpc 9 i386]
foreach vers {10 11 12 13 14 15 16 17 18 19} {
    if {${macports::os_major} != $vers} {
        lappend platforms $vers i386
    }
}
foreach vers {20 21 22} {
    if {${macports::os_major} != $vers} {
        lappend platforms $vers arm $vers i386
    } elseif {${macports::os_arch} eq "i386"} {
        lappend platforms $vers arm
    } else {
        lappend platforms $vers i386
    }
}
# build_arch values that could be considered "native" on platforms
# where 'uname -p' says 'i386'
set i386_archs [list x86_64 noarch i386]

if {[catch {set res [mportlistall]} result]} {
    puts stderr "$::errorInfo"
    error "listing all ports failed: $result"
}

proc get_distfiles {porturl subport check_platforms} {
    set portname_distfiles [list]
    if {[catch {mportopen $porturl [list subport $subport] {}} mport]} {
        ui_error "mportopen $porturl failed: $mport"
        #error "couldn't open portfile for $subport"
        return $portname_distfiles
    }
    set workername [ditem_key $mport workername]
    if {![catch {$workername eval {portfetch::fetch_init; return $all_dist_files}} all_dist_files]} {
        # has distfiles, add them to the list
        lappend portname_distfiles {*}$all_dist_files
    }

    array set portinfo [mportinfo $mport]
    mportclose $mport

    set variants [get_variants portinfo]
    foreach variant $variants {
        #ui_msg "$subport +${variant}"
        if {[catch {mportopen $porturl [list subport $subport] [list $variant +]} mport]} {
            ui_error "mportopen $porturl failed: $mport"
            # unfortunately quite a few ports have variants that fail
            continue
        }
        set workername [ditem_key $mport workername]
        if {![catch {$workername eval {portfetch::fetch_init; return $all_dist_files}} all_dist_files]} {
            lappend portname_distfiles {*}$all_dist_files
        }
        mportclose $mport
    }

    foreach {os_major os_arch} $check_platforms {
        #ui_msg "$subport with platform 'darwin $os_major $os_arch'"
        if {[catch {mportopen $porturl [list subport $subport os_major $os_major os_arch $os_arch] {}} mport]} {
            ui_error "mportopen $porturl failed: $mport"
            # sometimes whole subports are not defined on certain platforms
            continue
        }
        set workername [ditem_key $mport workername]
        if {![catch {$workername eval {portfetch::fetch_init; return $all_dist_files}} all_dist_files]} {
            lappend portname_distfiles {*}$all_dist_files
        }
        mportclose $mport
    }

    return $portname_distfiles
}

filemap create distfiles_to_keep
if {[info exists keepfile]} {
    set fd [open $keepfile r]
    while {[gets $fd line] != -1} {
        filemap set distfiles_to_keep $line 1
    }
    close $fd
} else {
    # generate set of desired distfiles
    set portfile_dir [file join ${tmpdir} from_archive]
    file delete -force ${portfile_dir}
    file mkdir ${portfile_dir}
    foreach {portname info_list} $result {
        array unset portinfo
        array set portinfo $info_list
        if {[lsearch -exact -nocase $portinfo(license) "nomirror"] >= 0} {
            # shouldn't be mirrored, so don't keep it if it is somehow there
            continue
        }
        foreach f [get_distfiles $portinfo(porturl) $portname $platforms] {
            filemap set distfiles_to_keep $f 1
        }
        foreach archive [glob -nocomplain -directory $packages_root ${portname}/*.${archive_type}] {
            exec -ignorestderr tar -xjq -C ${portfile_dir} -f $archive +PORTFILE
            file rename -force ${portfile_dir}/+PORTFILE ${portfile_dir}/Portfile
            # figure out the platform from the filename
            set segments [split [file tail $archive] .]
            set archs [split [lindex $segments end-1] -]
            set major [lindex [split [lindex $segments end-2] _] end]
            if {$major eq "any"} {
                set major ${macports::os_major}
            }
            set this_platforms [list]
            foreach arch $archs {
                if {$arch eq "arm64"} {
                    lappend this_platforms $major arm
                } elseif {$arch in $i386_archs} {
                    lappend this_platforms $major i386
                } else {
                    lappend this_platforms $major powerpc
                }
            }
            foreach f [get_distfiles file://${portfile_dir} $portname $this_platforms] {
                filemap set distfiles_to_keep $f 1
            }
        }
    }

    set fd [open [file join $workdir distfiles_keep.txt] w]
    puts $fd [join [filemap list distfiles_to_keep 1] \n]
    close $fd
    file delete -force ${portfile_dir}
}

# scan actual distfiles
# What we have in $distfiles_to_keep is filenames only, i.e. $dist_subdir is
# not taken into account. This is a lot simpler to deal with, even if it means
# we may keep a few files that could be deleted if there are identically named
# files in different subdirs. This may even be preferable with stealth updates
# since we don't know which version the archives were built from.
set dirlist [list $distfiles_root]
set fd [open [file join $workdir distfiles_delete.txt] w]
while {$dirlist ne ""} {
    set dir [lindex $dirlist end]
    set dirlist [lreplace ${dirlist}[set dirlist {}] end end]
    foreach f [glob -nocomplain -directory $dir *] {
        if {[file isfile $f] && [file mtime $f] < $start_time && ![filemap exists distfiles_to_keep [file tail $f]]} {
            puts $fd $f
        } elseif {[file isdirectory $f]} {
            lappend dirlist $f
        }
    }
}
close $fd
