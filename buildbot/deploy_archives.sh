#!/bin/sh

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
    ULPATH="./archive_staging"
fi

# private key to use for signing
if [[ -z "$PRIVKEY" ]]; then
    PRIVKEY=""
fi

# buildbot apparently doesn't run jobs on the master in different dirs or
# prevent them from running simultaneously
if [[ -z "$LOCKFILE" ]]; then
    LOCKFILE="./deploy.lock"
fi

while ! shlock -f $LOCKFILE -p $$; do
    sleep 1
done

if [[ ! -d $ULPATH ]]; then
    echo $ULPATH does not exist!
    rm $LOCKFILE
    exit 1
fi

if [[ -n "`ls ${ULPATH}`" ]]; then
    for archive in ${ULPATH}/*/*; do
        portname=$(basename $(dirname $archive))
        aname=$(basename $archive)
        echo deploying archive: $aname
        if [[ -n "$PRIVKEY" ]]; then
            openssl dgst -ripemd160 -sign "${PRIVKEY}" -out ${ULPATH}/${portname}/${aname}.rmd160 ${archive}
            if [[ $? -eq 0 && -f ${ULPATH}/${portname}/${aname}.rmd160 ]]; then
                chmod a+r ${ULPATH}/${portname}/${aname}.rmd160
            else
                rm -rf $ULPATH
                rm $LOCKFILE
                exit 1
            fi
        fi
    done
    
    if [[ -n "$DLHOST" ]]; then
        rsync -av --ignore-existing ${ULPATH}/ ${DLHOST}:${DLPATH}
    else
        rsync -av --ignore-existing ${ULPATH}/ ${DLPATH}
    fi
else
    echo $ULPATH appears to contain no archives
    ls -R $ULPATH
fi

# clean up after ourselves
rm $LOCKFILE
rm -rf $ULPATH
