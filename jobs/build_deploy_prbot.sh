#!/usr/bin/env bash

set -euo pipefail

if [ -z "${GOPATH:-}" ]; then
	printf >&2 "You must set \$GOPATH to the go workspace you want to use before calling this script.\n"
	exit 1
fi

MPBOT_PACKAGE_NAME=github.com/macports/mpbot-github
MPBOT_GITHUB_SRC=$GOPATH/src/$MPBOT_PACKAGE_NAME
PRBOT_CURRENT=$GOPATH/bin/prbot-current
PRBOT_NEXT=$GOPATH/bin/prbot-next

# Set up GOPATH, fetch or update source
mkdir -p "$GOPATH/src/github.com/mapcorts"
if [ -d "$MPBOT_GITHUB_SRC" ]; then
	git -C "$MPBOT_GITHUB_SRC" fetch --quiet || true # Ignore network problems assuming they are temporary
	git -C "$MPBOT_GITHUB_SRC" reset --quiet --hard origin/master
else
	git clone --quiet "https://$MPBOT_PACKAGE_NAME" "$MPBOT_GITHUB_SRC"
fi

# Find out whether there are new changes to be deployed
HEADREV=$(git -C "$MPBOT_GITHUB_SRC" rev-parse HEAD)
if [ -z "$HEADREV" ]; then
	printf >&2 "Could not determine head revision of Git repository %s\n" "$MPBOT_GITHUB_SRC"
	exit 1
fi

CURRENTREV=""
if [[ $(readlink "$PRBOT_CURRENT") =~ .*-([0-9a-f]+)$ ]]; then
	CURRENTREV=${BASH_REMATCH[1]}
fi

if [ "$HEADREV" = "$CURRENTREV" ]; then
	printf "Revision %s is already the newest revision. Nothing to do.\n" "$CURRENTREV"
	exit 0
fi

# Get dependencies
go get -u "$MPBOT_PACKAGE_NAME/pr/prbot"
# Install
go install "$MPBOT_PACKAGE_NAME/pr/prbot"

# Update symlink
mv "$GOPATH/bin/prbot" "$GOPATH/bin/prbot-$HEADREV"
rm -f "$PRBOT_NEXT"
ln -s "prbot-$HEADREV" "$PRBOT_NEXT"
mv -f "$PRBOT_NEXT" "$PRBOT_CURRENT"
