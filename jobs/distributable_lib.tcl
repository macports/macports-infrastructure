# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Library code for checking if ports are binary distributable.
# Used by the port_binary_distributable tool.

set check_deptypes [list depends_build depends_lib]

# Notes:
# 'Restrictive/Distributable' means a non-free license that nonetheless allows
# distributing binaries.
# 'Restrictive' means a non-free license that does not allow distributing
# binaries, and is thus not in the list.
# 'Permissive' is a catchall for other licenses that allow
# modification and distribution of source and binaries.
# 'Copyleft' means a license that requires source code to be made available,
# and derivative works to be licensed the same as the original.
# 'GPLConflict' should be added if the license conflicts with the GPL (and its
# variants like CeCILL and the AGPL) and is not in the list of licenses known
# to do so below.
# 'Noncommercial' means a license that prohibits commercial use.
set good_licenses [list afl agpl apache apsl artistic autoconf beopen bitstreamvera \
                   boost bsd bsd-old cc-by cc-by-sa cddl cecill cecill-b cecill-c cnri copyleft \
                   cpl curl epl fpll fontconfig freetype gd gfdl gpl \
                   gplconflict ibmpl ijg isc jasper lgpl libtool lppl mit \
                   mpl ncsa noncommercial openldap openssl permissive php \
                   psf public-domain qpl restrictive/distributable ruby \
                   sleepycat ssleay tcl/tk vim w3c wtfpl wxwidgets x11 zlib zpl]
foreach lic $good_licenses {
    set license_good($lic) 1
}

proc all_licenses_except { args } {
    set remaining $::good_licenses
    foreach arg $args {
        set remaining [lsearch -inline -all -not -exact $remaining $arg]
    }
    return $remaining
}

# keep these values sorted
array set license_conflicts \
    [list \
    afl [list agpl cecill gpl] \
    agpl [list afl apache-1 apache-1.1 apsl beopen bsd-old cc-by-1 cc-by-2 cc-by-2.5 cc-by-3 cc-by-sa cddl cecill cnri cpl epl gd gpl-1 gpl-2 gplconflict ibmpl lppl mpl noncommercial openssl php qpl restrictive/distributable ruby ssleay zpl-1] \
    agpl-1 [list apache freetype gpl-3 gpl-3+ lgpl-3 lgpl-3+] \
    apache [list agpl-1 cecill gpl-1 gpl-2] \
    apache-1 [list agpl gpl] \
    apache-1.1 [list agpl gpl] \
    apsl [list agpl cecill gpl] \
    beopen [list agpl cecill gpl] \
    bsd-old [list agpl cecill gpl] \
    cc-by-1 [list agpl cecill gpl] \
    cc-by-2 [list agpl cecill gpl] \
    cc-by-2.5 [list agpl cecill gpl] \
    cc-by-3 [list agpl cecill gpl] \
    cc-by-sa [list agpl cecill gpl] \
    cddl [list agpl cecill gpl] \
    cecill [list afl agpl apache apsl beopen bsd-old cc-by-1 cc-by-2 cc-by-2.5 cc-by-3 cc-by-sa cddl cnri cpl epl gd gplconflict ibmpl lppl mpl noncommercial openssl php qpl restrictive/distributable ruby ssleay zpl-1] \
    cnri [list agpl cecill gpl] \
    cpl [list agpl cecill gpl] \
    epl [list agpl cecill gpl] \
    freetype [list agpl-1 gpl-2] \
    gd [list agpl cecill gpl] \
    gpl [list afl apache-1 apache-1.1 apsl beopen bsd-old cc-by-1 cc-by-2 cc-by-2.5 cc-by-3 cc-by-sa cddl cnri cpl epl gd gplconflict ibmpl lppl mpl noncommercial openssl php qpl restrictive/distributable ruby ssleay zpl-1] \
    gpl-1 [list agpl apache gpl-3 gpl-3+ lgpl-3 lgpl-3+] \
    gpl-2 [list agpl apache freetype gpl-3 gpl-3+ lgpl-3 lgpl-3+] \
    gpl-3 [list agpl-1 gpl-1 gpl-2] \
    gpl-3+ [list agpl-1 gpl-1 gpl-2] \
    gplconflict [list agpl cecill gpl] \
    ibmpl [list agpl cecill gpl] \
    lgpl-3 [list agpl-1 gpl-1 gpl-2] \
    lgpl-3+ [list agpl-1 gpl-1 gpl-2] \
    lppl [list agpl cecill gpl] \
    mpl [list agpl cecill gpl] \
    noncommercial [list agpl cecill gpl] \
    openssl [list agpl cecill gpl] \
    opensslexception [all_licenses_except openssl ssleay] \
    php [list agpl cecill gpl] \
    qpl [list agpl cecill gpl] \
    restrictive/distributable [list agpl cecill gpl] \
    ruby [list agpl cecill gpl] \
    ssleay [list agpl cecill gpl] \
    zpl-1 [list agpl cecill gpl] \
    ]

# license database format:
# each line consists of "portname mtime {array}"
# where array is one or more {variant_string {dependencies license installs_libs [license_noconflict]}}

# load database if it exists
proc init_license_db {dbpath} {
    if {[file isfile ${dbpath}/license_db]} {
        set fd [open ${dbpath}/license_db r]
        while {[gets $fd entry] >= 0} {
            set ::license_db([lindex $entry 0]) [lrange $entry 1 end]
        }
        close $fd
    }
}

# write out database
proc write_license_db {dbpath} {
    if {![file isdirectory dbpath]} {
        file mkdir $dbpath
    }
    set fd [open ${dbpath}/license_db w]
    foreach portname [array names ::license_db] {
        puts $fd [list $portname {*}$::license_db($portname)]
    }
    close $fd
}

# purge old ports from database
proc cleanup_license_db {dbpath} {
    if {[file isfile ${dbpath}/license_db]} {
        set fd [open ${dbpath}/license_db r]
        set content [read $fd]
        close $fd
        set fd [open ${dbpath}/license_db w]
        foreach entry [split $content \n] {
            set portSearchResult [mportlookup [lindex $entry 0]]
            if {$portSearchResult ne ""} {
                array set portInfo [lindex $portSearchResult 1]
                set portfile_path [macports::getportdir $portInfo(porturl)]/Portfile
                if {[file mtime $portfile_path] == [lindex $entry 1]} {
                    puts $fd $entry
                }
                array unset portInfo
            }
        }
        close $fd
    }
}

# return deps and license for given port
proc infoForPort {portName variantInfo} {
    set portSearchResult [mportlookup $portName]
    if {[llength $portSearchResult] < 1} {
        puts stderr "Warning: port \"$portName\" not found"
        return {}
    }
    array set portInfo [lindex $portSearchResult 1]
    set portfile_path [macports::getportdir $portInfo(porturl)]/Portfile
    set variant_string [normalize_variants $variantInfo]

    # check if the port's info is already in the db
    if {[info exists ::license_db($portName)]} {
        set info_list $::license_db($portName)
        if {[file mtime $portfile_path] == [lindex $info_list 0]} {
            # keyed by normalized variant string
            array set info_array [lindex $info_list 1]
            if {[info exists info_array($variant_string)]} {
                return $info_array($variant_string)
            }
        } else {
            unset ::license_db($portName)
        }
    }

    set dependencyList [list]
    if {[catch {mportopen $portInfo(porturl) [list subport $portInfo(name)] $variantInfo} result]} {
        puts stderr "Warning: port \"$portName\" failed to open: $result"
        return {}
    } else {
        set mport $result
    }
    array unset portInfo
    array set portInfo [mportinfo $mport]
    # Closing the mport is actually fairly expensive and not really necessary
    #mportclose $mport

    foreach dependencyType $::check_deptypes {
        if {[info exists portInfo($dependencyType)] && $portInfo($dependencyType) ne ""} {
            foreach dependency $portInfo($dependencyType) {
                lappend dependencyList [string range $dependency [string last ":" $dependency]+1 end]
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
    if {[info exists portInfo(license_noconflict)]} {
        lappend ret $portInfo(license_noconflict)
    }

    # update the db
    set info_array($variant_string) $ret
    set ::license_db($portName) [list [file mtime $portfile_path] [array get info_array]]

    return $ret
}

# return license with any trailing dash followed by a number and/or plus sign removed
set remove_version_re {[0-9.+]+}
proc remove_version {license} {
    set dash [string last - $license]
    if {$dash != -1 && [regexp $::remove_version_re [string range $license $dash+1 end]]} {
        return [string range $license 0 $dash-1]
    } else {
        return $license
    }
}

proc check_licenses {portName variantInfo} {
    array set portSeen {}
    set failures {}
    set top_info [infoForPort $portName $variantInfo]
    if {$top_info eq {}} {
        return 1
    }
    set top_license [lindex $top_info 1]
    foreach noconflict_port [lindex $top_info 3] {
        set noconflict_ports($noconflict_port) 1
    }
    set top_license_names [list]
    # check that top-level port's license(s) are good
    foreach sublist $top_license {
        # each element may be a list of alternatives (i.e. only one need apply)
        set any_good 0
        set sub_names [list]
        foreach full_lic $sublist {
            # chop off any trailing version number
            set lic [remove_version $full_lic]
            # add name to the list for later
            lappend sub_names $lic
            if {[info exists ::license_good([string tolower $lic])]} {
                set any_good 1
            }
        }
        lappend top_license_names $sub_names
        if {!$any_good} {
            lappend failures "\"$portName\" is not distributable because its license \"$lic\" is not known to be distributable"
        }
    }

    # start with deps of top-level port
    set portPaths [dict create [lindex $top_info 0] [list]]
    set portList [lindex $top_info 0]
    foreach aPort $portList {
        dict set portPaths $aPort [list]
    }

    while {[llength $portList] > 0} {
        set aPort [lindex $portList 0]
        set portList [lreplace $portList 0 0]
        if {[info exists portSeen($aPort)] && $portSeen($aPort) eq 1} {
            continue
        }
        # mark as seen and remove from the list
        set portSeen($aPort) 1
        if {[info exists noconflict_ports($aPort)]} {
            continue
        }

        set aPortInfo [infoForPort $aPort $variantInfo]
        if {$aPortInfo eq {}} {
            continue
        }
        set aPortLicense [lindex $aPortInfo 1]
        set installs_libs [lindex $aPortInfo 2]
        if {!$installs_libs} {
            continue
        }
        set parentPath [list {*}[dict get $portPaths $aPort] $aPort]
        foreach sublist $aPortLicense {
            set any_good 0
            set any_compatible 0
            # check that this dependency's license(s) are good
            foreach full_lic $sublist {
                set lic [remove_version [string tolower $full_lic]]
                if {[info exists ::license_good($lic)]} {
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
                        if {![info exists ::license_conflicts([string tolower $top_lic])]
                            || ([lsearch -sorted $::license_conflicts([string tolower $top_lic]) $lic] == -1
                            && [lsearch -sorted $::license_conflicts([string tolower $top_lic]) [string tolower $full_lic]] == -1)} {
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
                lappend failures "\"$portName\" is not distributable because its dependency \"$aPort\" has license \"$full_lic\" which is not known to be distributable: [join $parentPath " -> "]"
            } elseif {!$any_compatible} {
                lappend failures "\"$portName\" is not distributable because its license \"$top_lic\" conflicts with license \"$full_lic\": [join $parentPath " -> "]"
            }
        }

        # skip deps that are explicitly stated to not conflict
        array unset aPort_noconflict_ports
        foreach noconflict_port [lindex $aPortInfo 3] {
            set aPort_noconflict_ports($noconflict_port) 1
        }
        # add its deps to the list
        foreach possiblyNewPort [lindex $aPortInfo 0] {
            if {![info exists portSeen($possiblyNewPort)] && ![info exists aPort_noconflict_ports($possiblyNewPort)]} {
                lappend portList $possiblyNewPort
                dict set portPaths $possiblyNewPort $parentPath
            }
        }
    }

    if {[llength $failures] ne 0} {
        return [list 1 $failures]
    } else {
        return [list 0 [list "\"$portName\" is distributable"]]
    }
}

# given a variant string, return an array of variations
set split_variants_re {([-+])([[:alpha:]_]+[\w\.]*)}
proc split_variants {variants} {
    set result [list]
    set l [regexp -all -inline -- $::split_variants_re $variants]
    foreach { match sign variant } $l {
        lappend result $variant $sign
    }
    return $result
}

# given an array of variations, return a variant string in normalized form
proc normalize_variants {variations} {
    array set varray $variations
    set variant_string ""
    foreach vname [lsort -ascii [array names varray]] {
        append variant_string $varray($vname)${vname}
    }
    return $variant_string
}
