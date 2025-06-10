#! /bin/bash

set -e

# download server hostname
if [[ -z "$DLHOST" ]]; then
    DLHOST=""
fi

# path where download server keeps archives
if [[ -z "$DLPATH" ]]; then
    DLPATH="./deployed_archives"
fi

# path where archives get uploaded to buildmaster
if [[ -z "$ULPATH" ]]; then
    # workaround for buildbot not accepting WithProperties in env
    if [[ -n "$1" ]]; then
        ULPATH="$1"
    else
        ULPATH="./archive_staging"
    fi
fi

# private key to use for signing
if [[ -z "$PRIVKEY" ]]; then
    PRIVKEY=""
fi
# secondary private key to use for signing
if [[ -z "$PRIVKEY2" ]]; then
    PRIVKEY2=""
fi
# signify(1) executable
if [[ -z "$SIGNIFY" ]]; then
    SIGNIFY="/usr/bin/signify-openbsd"
fi

# Buildbot apparently doesn't run jobs on the master in different dirs or
# prevent them from running simultaneously.
# Always lock, because multiple builders may be deploying files with
# the same names at the same time, so unique subdirs are not enough.
# See: https://trac.macports.org/ticket/62977
if [[ -z "$LOCKFILE" ]]; then
    LOCKFILE="./deploy.lock"
fi

echo Acquiring lock...
if [[ "`uname -s`" = "Darwin" ]]; then
    SLEPT=0
    while ! shlock -f "$LOCKFILE" -p $$; do
        sleep 1
        let SLEPT="$SLEPT + 1"
        if [[ "$SLEPT" -gt 600 ]]; then
            echo Timeout acquiring lock, continuing anyway...
            break
        fi
    done
else
    if ! lockfile -1 -r 600 "$LOCKFILE"; then
        echo Timeout acquiring lock, continuing anyway...
    fi
fi

if [[ ! -d "$ULPATH" ]]; then
    echo "$ULPATH does not exist!"
    rm -f "$LOCKFILE"
    exit 1
fi

if [[ -n "`ls ${ULPATH}`" ]]; then
    for archive in ${ULPATH}/*/*; do
        portname="$(basename "$(dirname "$archive")")"
        aname="$(basename "$archive")"
        echo "deploying archive: $aname"
        for CUR_PRIVKEY in "$PRIVKEY" "$PRIVKEY2"; do
            if [[ "${CUR_PRIVKEY##*.}" = "pem" ]]; then
                openssl dgst -ripemd160 -sign "$CUR_PRIVKEY" -out "${ULPATH}/${portname}/${aname}.rmd160" "$archive"
                if [[ $? -eq 0 && -f "${ULPATH}/${portname}/${aname}.rmd160" ]]; then
                    chmod a+r "${ULPATH}/${portname}/${aname}.rmd160"
                else
                    rm -rf "$ULPATH"
                    rm -f "$LOCKFILE"
                    exit 1
                fi
            elif [[ "${CUR_PRIVKEY##*.}" = "sec" ]]; then
                "$SIGNIFY" -S -s "$CUR_PRIVKEY" -x "${ULPATH}/${portname}/${aname}.sig" -m "$archive"
                if [[ $? -eq 0 && -f "${ULPATH}/${portname}/${aname}.sig" ]]; then
                    chmod a+r "${ULPATH}/${portname}/${aname}.sig"
                else
                    rm -rf "$ULPATH"
                    rm -f "$LOCKFILE"
                    exit 1
                fi
            fi
        done
    done

    if [[ -n "$DLHOST" ]]; then
        rsync -rlDzv --ignore-existing "${ULPATH}/" "${DLHOST}:${DLPATH}"
    else
        rsync -rlDzv --ignore-existing "${ULPATH}/" "${DLPATH}"
    fi
else
    echo "$ULPATH appears to contain no archives"
    ls -R "$ULPATH"
fi

# clean up after ourselves
rm -f "$LOCKFILE"
rm -rf "$ULPATH"

