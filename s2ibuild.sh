#!/usr/bin/env bash

set -e
set -o pipefail

[ "$PLUGIN_BUILDER_IMAGE" == "" ] && echo "You must set the BUILDER parameter in settings" && exit 1

if [ "$PLUGIN_EXTRACT" == "true" ]; then
    [ "$PLUGIN_EXTRACT_PATH" == "" ] && echo "You must set the extract-path in settings" && exit 1 
	[ "$PLUGIN_CACHE_DIR" == "" ] && echo "You must set the cache-dir in settings" && exit 1 
fi

if [ "$PLUGIN_PUSH" == "true" ]; then
    [ "$PLUGIN_TARGET_IMAGE" == "" ] && echo "You must set the target-image in settings" && exit 1     
fi

if [ "$PLUGIN_SOURCE" == "" ]; then
    PLUGIN_SOURCE=${DRONE_WORKSPACE_BASE}
fi

if [ "$PLUGIN_CERT" != "" ]; then
    mkdir -p /etc/docker/certs.d/$PLUGIN_REGISTRY
fi

OPTS=""
if [ "$PLUGIN_INSECURE" == "true" ] && [ "$PLUGIN_REGISTRY" != "" ]; then
    OPTS=' --insecure-registry='$PLUGIN_REGISTRY
fi

# build s2i options
S2IOPTS=""
if [ "$PLUGIN_INCREMENTAL" == "true" ]; then
    S2IOPTS="--incremental"
fi

# Docker daemon checker
RETVAL="ko"
checkdocker(){
    res=$(echo -e "GET /version HTTP/1.0\r\n" | nc -U /var/run/docker.sock 2>/dev/null)
    echo "$res" | grep "Platform" && RETVAL="ok" || :
}

# Launching Docker

# nohup dockerd -s overlay2 $OPTS </dev/null >/dev/null 2>&1 &
nohup dockerd -s overlay2 $OPTS &

# Wait for docker daemon
echo -e "Waiting for docker daemon"

COUNT=0
checkdocker || :
until [ $RETVAL == "ok" ]; do
    sleep 1
    COUNT=$((COUNT+1))
    [ $COUNT -gt 10 ] && echo "Docker cannot start" && exit 1
    checkdocker || :
done
echo

#prepare build environment
SRC_DIR=$(mktemp -d)

echo "Docker daemon is ready, building..."

# try to login if needed
if [ "$PLUGIN_USERNAME" != "" ] && [ "$PLUGIN_PASSWORD" != "" ]; then
    echo "Login to registry..."
    docker login $PLUGIN_REGISTRY --username "$PLUGIN_USERNAME" --password "$PLUGIN_PASSWORD"
fi

echo "Building image"
set -x
target=${RANDOM}-${RANDOM}-${RANDOM}-${RANDOM}
s2i build ${PLUGIN_SOURCE} $S2IOPTS --context-dir=${PLUGIN_CONTEXT-./} ${PLUGIN_BUILDER_IMAGE} ${target} --keep-symlinks --env=DRONE=true || exit 1
set +x

if [ "$PLUGIN_EXTRACT" == "true" ] && [ "$PLUGIN_EXTRACT_PATH" != "" ] && [ "$PLUGIN_CACHE_DIR" != "" ]; then
	echo "Copying build-output from builder image to PLUGIN_CACHE_DIR"
	set -x
    build_cid=$(docker create ${target} || exit 1)
    docker cp ${build_cid}:${PLUGIN_EXTRACT_PATH}/. ${PLUGIN_CACHE_DIR}
    docker rm ${build_cid}
	set +x
fi

# push tag if wanted
if [ "$PLUGIN_PUSH" == "true" ]; then
    echo "Pushing $PLUGIN_TARGET_IMAGE"

    for tag in ${PLUGIN_TAGS//,/" "}; do
        docker push ${PLUGIN_TARGET_IMAGE}:${tag} || exit 1
    done
    echo "Pushed"
fi

set -x
docker system prune -f || :

set +x

exit 0
