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


for archive in ${ULPATH}/*/*; do
    portname=$(basename $(dirname $archive))
    aname=$(basename $archive)
    echo deploying archive: $aname
    if [[ -n "$PRIVKEY" ]]; then
        openssl dgst -ripemd160 -sign "${PRIVKEY}" -out ${ULPATH}/${portname}/${aname}.rmd160 ${archive}
    fi
done

if [[ -n "$DLHOST" ]]; then
    rsync -av --ignore-existing ${ULPATH}/ ${DLHOST}:${DLPATH}
else
    rsync -av --ignore-existing ${ULPATH}/ ${DLPATH}
fi

# clean up after ourselves
rm -rf $ULPATH
