#!/usr/bin/env bash

##
# This script downloads and builds a docker container from the Dockerfile in
# the current directory.
#
# 1. update the git repository this script resides in
# 2. rebuild the container if
#   2.1 the Dockerfile or any of the files in its directory changed, or
#   2.2 the container is older than a week, to update dependencies.
# 3. retag the container as paste:latest
# 4. kill the current container, so that systemd will restart it

set -euo pipefail

# The number of old containers to keep for this Dockerfile
KEEP_OLD_VERSIONS=5

THISDIR=$(cd "$(dirname "$0")" && pwd)

git -C "$THISDIR" fetch --quiet || true # Ignore network problems, assuming they are temporary
OLDREV=$(git -C "$THISDIR" log -1 --pretty=%H "$THISDIR")
git -C "$THISDIR" reset --quiet --hard origin/master
NEWREV=$(git -C "$THISDIR" log -1 --pretty=%H "$THISDIR")

if [ "$OLDREV" != "$NEWREV" ]; then
	# The container's folder changed. Since this potentially also affects this
	# script, re-execute the script itself.
	printf "Revision changed from %s to %s, re-executing...\n" "$OLDREV" "$NEWREV"
	exec "$0" "$@"
	exit 1
fi

cd "$THISDIR"
CONTAINERNAME=$(basename "$(readlink -f .)")
TIMESTAMP=$(date +%G-%V)

# Check whether the current container was already built for this version
IMAGES=$(docker images --format "{{.ID}}" "$CONTAINERNAME:$NEWREV-$TIMESTAMP" | wc -l)
if [ "$IMAGES" -gt 0 ]; then
	printf "Container %s is already the newest version. Nothing to do\n" "$CONTAINERNAME"
	exit 0
fi

printf "Rebuilding container %s with tag %s\n" "$CONTAINERNAME" "$NEWREV-$TIMESTAMP"
docker build --no-cache -t "$CONTAINERNAME:$NEWREV-$TIMESTAMP" .

printf "Rebuild successful, tagging as %s:latest\n" "$CONTAINERNAME"
docker tag "$CONTAINERNAME:$NEWREV-$TIMESTAMP" "$CONTAINERNAME:latest"

# Stop currently running container to force systemd to restart it
RUNNING_CONTAINER_ID=$(docker container inspect --format "{{.ID}}" "$CONTAINERNAME" 2>/dev/null || true)
if [ -n "$RUNNING_CONTAINER_ID" ]; then
	printf "Stopping running instance %s of container %s\n" "$RUNNING_CONTAINER_ID" "$CONTAINERNAME"
	docker stop "$RUNNING_CONTAINER_ID"
fi

# Cleanup old images
CLEANUP_IMAGES_STRING=$(docker images --format "{{.ID}}" --filter "before=$CONTAINERNAME:$NEWREV-$TIMESTAMP" "$CONTAINERNAME" | sed "1,${KEEP_OLD_VERSIONS}d" | tr '\n' ' ')
if [ -n "$CLEANUP_IMAGES_STRING" ]; then
	IFS=' ' read -r -a CLEANUP_IMAGES <<<"$CLEANUP_IMAGES_STRING"
	docker rmi "${CLEANUP_IMAGES[@]}"
fi

printf "Updated %s to %s\n" "$CONTAINERNAME" "$NEWREV-$TIMESTAMP"
exit 0
