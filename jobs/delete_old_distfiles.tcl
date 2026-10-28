#! /usr/bin/env port-tclsh

# Find all distfiles that exist under distfiles_root and are not needed by
# the current version of any port or by a version existing as a package
# under packages_root.

set start_time [clock seconds]

if {[llength $argv] < 3} {
    puts "Usage: $argv0 [-n] [-m min_age] [-k keepfile] indexvars_dir distfiles_root packages_root"
    exit 1
}

set min_age 315576000
set keep_only 0
for {set i 0} {$i < [llength $argv]-3} {incr i} {
    switch [lindex $argv $i] {
        -k {
            incr i
            set keepfile [lindex $argv $i]
        }
        -m {
            incr i
            set min_age [lindex $argv $i]
        }
        -n {
            set keep_only 1
        }
    }
}

lassign [lrange $argv $i end] indexvars_dir distfiles_root packages_root
if {[info exists env(TMPDIR)]} {
    set tmpdir $env(TMPDIR)
} else {
    set tmpdir /tmp
}
set workdir [file normalize [pwd]]

set platforms [list 9 powerpc 9 i386]
foreach vers {10 11 12 13 14 15 16 17 18 19} {
    lappend platforms $vers i386
}
foreach vers {20 21 22 23 24 25} {
    lappend platforms $vers arm $vers i386
}
foreach vers {27} {
    lappend platforms $vers arm
}

set worker_script {

proc get_variants {portinfo} {
    if {![dict exists $portinfo vinfo]} {
        return {}
    }
    set variants [list]
    dict for {vname variant} [dict get $portinfo vinfo] {
        if {![dict exists $variant is_default] || [dict get $variant is_default] ne "+"} {
            lappend variants $vname
        }
    }
    return $variants
}

package require Thread
package require macports
mportinit

set alldistfiles_script {
    catch {package require portfetch_run}
    portfetch::fetch_init
    return $all_dist_files
}

proc get_port_distfiles {porturl subport check_archs} {
    global alldistfiles_script macports::build_arch
    set distfiles_to_keep [dict create]
    if {[catch {mportopen $porturl [dict create subport $subport] {}} mport]} {
        ui_error "mportopen $porturl failed: $mport"
        return $distfiles_to_keep
    }
    set workername [ditem_key $mport workername]
    if {![catch {$workername eval $alldistfiles_script} all_dist_files]} {
        # has distfiles, add them to the list
        foreach f $all_dist_files {
            dict set distfiles_to_keep $f 1
        }
    }

    set portinfo [mportinfo $mport]
    mportclose $mport

    set variants [get_variants $portinfo]
    foreach variant $variants {
        #ui_msg "$subport +${variant}"
        if {[catch {mportopen $porturl [dict create subport $subport] [dict create $variant +]} mport]} {
            ui_error "mportopen $porturl failed: $mport"
            # unfortunately quite a few ports have variants that fail
            continue
        }
        set workername [ditem_key $mport workername]
        if {![catch {$workername eval $alldistfiles_script} all_dist_files]} {
            foreach f $all_dist_files {
                dict set distfiles_to_keep $f 1
            }
        }
        mportclose $mport
    }

    # try with different build_archs
    foreach arch $check_archs {
        if {$arch eq $build_arch || $arch eq "noarch"} {
            continue
        }
        #ui_msg "$subport with build_arch '$arch'"
        if {[catch {mportopen $porturl [dict create subport $subport build_arch $arch] {}} mport]} {
            ui_error "mportopen $porturl failed: $mport"
            # sometimes whole subports are not defined on certain platforms
            continue
        }
        set workername [ditem_key $mport workername]
        if {![catch {$workername eval $alldistfiles_script} all_dist_files]} {
            foreach f $all_dist_files {
                dict set distfiles_to_keep $f 1
            }
        }
        mportclose $mport
    }

    return $distfiles_to_keep
}

proc get_archive_distfiles {portname packages_root portfile_dir} {
    global macports::os_platform macports::os_major macports::build_arch \
           alldistfiles_script
    set distfiles_to_keep [dict create]
    set archive_type tbz2
    set glob_pattern "${portname}/*.{${os_platform},any}_{${os_major},any}.*.${archive_type}"
    set archive_list [glob -nocomplain -directory $packages_root $glob_pattern]
    set porturl file://${portfile_dir}
    foreach archive $archive_list {
        puts "$os_platform $os_major processing $archive"
        try {
            exec -ignorestderr tar -xjq -C ${portfile_dir} -f $archive +PORTFILE
            file rename -force ${portfile_dir}/+PORTFILE ${portfile_dir}/Portfile
            # figure out the platform from the filename
            set segments [split [file tail $archive] .]
            set archs [split [lindex $segments end-1] -]
            # name,version,revision,variants string
            set id [join [lrange $segments 0 end-3] .]
            set plus [string first + $id]
            if {$plus == -1} {
                set variations {}
            } else {
                set variants [string range $id $plus end]
                set variations [macports::_variants_to_variations $variants]
            }
            set this_archive_distfiles [dict create]

            foreach arch $archs {
                set optionsdict [dict create subport $portname]
                if {$arch ne $build_arch && $arch ne "noarch"} {
                    dict set optionsdict build_arch $arch
                }
                if {[catch {mportopen $porturl $optionsdict $variations} mport]} {
                    ui_error "mportopen $porturl failed: $mport"
                    # sometimes whole subports are not defined on certain platforms
                    continue
                }
                set workername [ditem_key $mport workername]
                if {![catch {$workername eval $alldistfiles_script} all_dist_files]} {
                    foreach f $all_dist_files {
                        dict set this_archive_distfiles $f 1
                    }
                }
                mportclose $mport
            }

            set distfiles_to_keep [dict merge $distfiles_to_keep $this_archive_distfiles]
        } on error {err} {
            puts stderr "$os_platform $os_major error on ${archive}: $err"
        }
    }
    return $distfiles_to_keep
}

proc load_platform_vars {platform indexvars_dir} {
    set filename [file join $indexvars_dir macosx_$platform]
    set fd [open $filename r]
    gets $fd var_overrides
    close $fd
    macports::override_vars $var_overrides
}

proc get_platform_distfiles {packages_root portfile_dir workdir} {
    try {
        global macports::os_major macports::os_arch
        file mkdir $portfile_dir
        set plat ${os_major}_${os_arch}
        set todo_file ${plat}.todo.txt
        set distfiles_file ${plat}.distfiles.txt
        if {[file isfile ${workdir}/${todo_file}] && [file isfile ${workdir}/${distfiles_file}]} {
            set fd [open ${workdir}/${todo_file} r]
            set todo [read -nonewline $fd]
            close $fd
            set fd [open ${workdir}/${distfiles_file} r]
            gets $fd distfiles_to_keep
            close $fd
        } else {
            set todo [mportlistall]
            set distfiles_to_keep [dict create]
        }
        set extra_archs [list]
        if {$os_arch eq "i386"} {
            if {$os_major == 9} {
                lappend extra_archs x86_64
            } elseif {$os_major <= 17} {
                lappend extra_archs i386
            }
        } elseif {$os_arch eq "powerpc"} {
            lappend extra_archs ppc64
        }

        set index 0
        foreach {portname portinfo} $todo {
            if {[lsearch -exact -nocase [dict get $portinfo license] "nomirror"] >= 0} {
                # shouldn't be mirrored, so don't keep it if it is somehow there
                incr index 2
                continue
            }
            set thisport_distfiles [get_port_distfiles [dict get $portinfo porturl] $portname $extra_archs]
            set distfiles_to_keep [dict merge $distfiles_to_keep $thisport_distfiles]
            set archive_distfiles [get_archive_distfiles $portname $packages_root $portfile_dir]
            set distfiles_to_keep [dict merge $distfiles_to_keep $archive_distfiles]
            # save after every 100 ports
            if {$index % 200 == 0} {
                set fd [open ${workdir}/${distfiles_file}.new w]
                puts $fd $distfiles_to_keep
                close $fd
                set fd [open ${workdir}/${todo_file}.new w]
                puts $fd [lrange $todo $index end]
                close $fd
                file rename -force ${workdir}/${distfiles_file}.new ${workdir}/${distfiles_file}
                file rename -force ${workdir}/${todo_file}.new ${workdir}/${todo_file}
            }
            incr index 2
        }
        return $distfiles_to_keep
    } on error {err} {
        puts stderr "get_platform_distfiles failed for ${os_major} ${os_arch}: $err"
    }
    return {}
}

thread::wait
}
# end worker_script

set distfiles_to_keep [dict create]
if {[info exists keepfile]} {
    set fd [open $keepfile r]
    while {[gets $fd line] != -1} {
        dict set distfiles_to_keep $line 1
    }
    close $fd
} else {
    package require Thread
    # generate set of desired distfiles
    set portfile_dir [file join ${tmpdir} from_archive]
    file delete -force ${portfile_dir}
    set threads [dict create]
    # start a thread per platform
    foreach {os_major os_arch} $platforms {
        set platform ${os_major}_${os_arch}
        set tid [thread::create -preserved $worker_script]
        dict set threads $platform $tid
        thread::send $tid [list load_platform_vars $platform $indexvars_dir]
    }

    # Start jobs
    dict for {platform tid} $threads {
        set platform_portfile_dir ${portfile_dir}/${platform}
        file mkdir $platform_portfile_dir
        thread::send -async $tid [list get_platform_distfiles $packages_root $platform_portfile_dir $workdir] distfiles_to_keep_$tid
    }

    # combine all results
    foreach tid [dict values $threads] {
        if {![info exists distfiles_to_keep_$tid]} {
            vwait distfiles_to_keep_$tid
        }
        if {[catch {dict merge $distfiles_to_keep [set distfiles_to_keep_$tid]} merge_result]} {
            puts stderr "failed to merge dicts: $merge_result"
            puts stderr "new dict contents: [set distfiles_to_keep_$tid]"
        } else {
            set distfiles_to_keep $merge_result
        }
        thread::release $tid
    }

    set fd [open [file join $workdir distfiles_keep.txt] w]
    puts $fd [join [dict keys $distfiles_to_keep] \n]
    close $fd
    file delete -force ${portfile_dir}
}

# scan actual distfiles
# What we have in $distfiles_to_keep is filenames only, i.e. $dist_subdir is
# not taken into account. This is a lot simpler to deal with, even if it means
# we may keep a few files that could be deleted if there are identically named
# files in different subdirs. This may even be preferable with stealth updates
# since we don't know which version the archives were built from.
if {!$keep_only} {
    set dirlist [list $distfiles_root]
    set fd [open [file join $workdir distfiles_delete.txt] w]
    while {[llength $dirlist] > 0} {
        set dir [lindex $dirlist end]
        set dirlist [lreplace ${dirlist}[set dirlist {}] end end]
        foreach f [glob -nocomplain -directory $dir *] {
            if {[file isfile $f] && ($start_time - [file mtime $f]) >= $min_age && ![dict exists $distfiles_to_keep [file tail $f]]} {
                puts $fd $f
            } elseif {[file isdirectory $f]} {
                lappend dirlist $f
            }
        }
    }
    close $fd
}
