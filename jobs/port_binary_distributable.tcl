#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# $Id$
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

array set portsSeen {}

set check_deptypes {depends_build depends_lib}

set good_licenses {agpl apache apsl artistic boost bsd cecill cpl curl
                   fontconfig freebsd freetype gfdl gpl ibmpl ijg jasper
                   lgpl libpng mit mpl openssl php psf qpl public-domain
                   ruby sleepycat ssleay x11 zlib zpl}
foreach lic $good_licenses {
    set license_good($lic) 1
}
# keep these values sorted
array set license_conflicts \
    {agpl {cecill gpl}
    apache {cecill gpl}
    apsl {cecill gpl}
    cpl {cecill gpl}
    cecill {agpl apache apsl cpl ibmpl mpl openssl php qpl ssleay zpl-1}
    freetype {gpl-2}
    gpl {agpl apache apsl cpl ibmpl mpl openssl php qpl ssleay zpl-1}
    gpl-1 {gpl-3 gpl-3+ lgpl-3 lgpl-3+}
    gpl-2 {freetype gpl-3 gpl-3+ lgpl-3 lgpl-3+}
    gpl-3 {gpl-1 gpl-2}
    gpl-3+ {gpl-1 gpl-2}
    ibmpl {cecill gpl}
    lgpl-3 {gpl-1 gpl-2}
    lgpl-3+ {gpl-1 gpl-2}
    mpl {cecill gpl}
    openssl {cecill gpl}
    php {cecill gpl}
    qpl {cecill gpl}
    ssleay {cecill gpl}
    zpl-1 {cecill gpl}}

proc printUsage {} {
    puts "Usage: $::argv0 \[-hvV\] \[-t macports-tcl-path\] port-name \[variants...\]"
    puts "  -h    This help"
    puts "  -t    Give a different location for the base MacPorts Tcl"
    puts "        file (defaults to /Library/Tcl)"
    puts "  -v    verbose output"
    puts "  -V    show version and MacPorts version being used"
    puts ""
    puts "port-name is the name of a port to check"
    puts "variants is the list of variants to enable/disable: +one -two..."
}


# return deps and license for given port
proc infoForPort {portName variantInfo} {
    global check_deptypes
    set dependencyList {}
    set portSearchResult [mportlookup $portName]
    if {[llength $portSearchResult] < 1} {
        puts "Warning: port \"$portName\" not found"
        return {}
    }
    array set portInfo [lindex $portSearchResult 1]
    set mport [mportopen $portInfo(porturl) [list subport $portName] $variantInfo]
    array unset portInfo
    array set portInfo [mportinfo $mport]
    mportclose $mport

    foreach dependencyType $check_deptypes {
        if {[info exists portInfo($dependencyType)] && [string length $portInfo($dependencyType)] > 0} {
            foreach dependency $portInfo($dependencyType) {
                set afterColon [expr {[string last ":" $dependency] + 1}]
                lappend dependencyList [string range $dependency $afterColon end]
            }
        }
    }

    set ret [list $dependencyList $portInfo(license)]
    if {[info exists portInfo(installs_libs)]} {
        lappend ret $portInfo(installs_libs)
    } else {
        # when in doubt, assume code from the dep is incorporated
        lappend ret yes
    }
    return $ret
}

# return license with any trailing dash followed by a number and/or plus sign removed
proc remove_version {license} {
    set dash [string last - $license]
    if {$dash != -1 && [regexp {[0-9.+]+} [string range $license [expr $dash + 1] end]]} {
        return [string range $license 0 [expr $dash - 1]]
    } else {
        return $license
    }
}

proc check_licenses {portName variantInfo verbose} {
    global license_good license_conflicts
    array set portSeen {}
    set top_info [infoForPort $portName $variantInfo]
    set top_license [lindex $top_info 1]
    set top_license_names {}
    # check that top-level port's license(s) are good
    foreach sublist $top_license {
        # each element may be a list of alternatives (i.e. only one need apply)
        set any_good 0
        set sub_names {}
        foreach full_lic $sublist {
            # chop off any trailing version number
            set lic [remove_version [string tolower $full_lic]]
            # add name to the list for later
            lappend sub_names $lic
            if {[info exists license_good($lic)]} {
                set any_good 1
            }
        }
        lappend top_license_names $sub_names
        if {!$any_good} {
            if {$verbose} {
                puts "'$portName' has license '$lic' which is not known to be distributable"
            }
            return 1
        }
    }

    # start with deps of top-level port
    set portList [lindex $top_info 0]
    while {[llength $portList] > 0} {
        set aPort [lindex $portList 0]
        # mark as seen and remove from the list
        set portSeen($aPort) 1
        set portList [lreplace $portList 0 0]

        set aPortInfo [infoForPort $aPort $variantInfo]
        set aPortLicense [lindex $aPortInfo 1]
        set installs_libs [lindex $aPortInfo 2]
        if {!$installs_libs} {
            continue
        }
        foreach sublist $aPortLicense {
            set any_good 0
            set any_compatible 0
            # check that this dependency's license(s) are good
            foreach full_lic $sublist {
                set lic [remove_version [string tolower $full_lic]]
                if {[info exists license_good($lic)]} {
                    set any_good 1
                } else {
                    # no good being compatible with other licenses if it's not distributable itself
                    continue
                }

                # ... and that they don't conflict with the top-level port's
                set any_conflict 0
                foreach top_sublist [concat $top_license $top_license_names] {
                    set any_sub_compatible 0
                    foreach top_lic $top_sublist {
                        if {![info exists license_conflicts([string tolower $top_lic])]
                            || ([lsearch -sorted $license_conflicts([string tolower $top_lic]) $lic] == -1
                            && [lsearch -sorted $license_conflicts([string tolower $top_lic]) [string tolower $full_lic]] == -1)} {
                            set any_sub_compatible 1
                            break
                        }
                    }
                    if {!$any_sub_compatible} {
                        set any_conflict 1
                        break
                    }
                }
                if {!$any_conflict} {
                    set any_compatible 1
                    break
                }
            }

            if {!$any_good} {
                if {$verbose} {
                    puts "dependency '$aPort' has license '$lic' which is not known to be distributable"
                }
                return 1
            }
            if {!$any_compatible} {
                if {$verbose} {
                    puts "dependency '$aPort' has license '$full_lic' which conflicts with license '$top_lic' from '$portName'"
                }
                return 1
            }
        }

        # add its deps to the list
        foreach possiblyNewPort [lindex $aPortInfo 0] {
            if {![info exists portSeen($possiblyNewPort)]} {
                lappend portList $possiblyNewPort
            }
        }
    }

    if {$verbose} {
        puts "$portName is distributable"
    }
    return 0
}


# Begin

set macportsTclPath /Library/Tcl
set verbose 0
set showVersion 0

while {[string index [lindex $::argv 0] 0] == "-" } {
    switch [string range [lindex $::argv 0] 1 end] {
        h {
            printUsage
            exit 0
        }
        t {
            if {[llength $::argv] < 2} {
                puts "-t needs a path"
                printUsage
                exit 2
            }
            set macportsTclPath [lindex $::argv 1]
            set ::argv [lrange $::argv 1 end]
        }
        v {
             set verbose 1
        }
        V {
            set showVersion 1
        }
        default {
            puts "Unknown option [lindex $::argv 0]"
            printUsage
            exit 2
        }
    }
    set ::argv [lrange $::argv 1 end]
}

source ${macportsTclPath}/macports1.0/macports_fastload.tcl
package require macports
mportinit

if {$showVersion} {
    puts "Version $MY_VERSION"
    puts "MacPorts version [macports::version]"
    exit 0
}

if {[llength $::argv] == 0} {
    puts "Error: missing port-name"
    printUsage
    exit 2
}
set portName [lindex $::argv 0]
set ::argv [lrange $::argv 1 end]

array set variantInfo {}
foreach variantSetting $::argv {
    set flag [string index $variantSetting 0]
    set variantName [string range $variantSetting 1 end]
    set variantInfo($variantName) $flag
}

exit [check_licenses $portName [array get variantInfo] $verbose]
