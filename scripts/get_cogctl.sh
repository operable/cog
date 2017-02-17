#!/bin/bash

set -euo pipefail

# Get cogctl executable for incorporation into a Cog image
#
# Eventually, we'll have a proper artifact repository for our cogctl
# binaries, but until then, we can extract the binary out of their own
# Docker container. Since we can't do that from within the Cog image
# building process, we need to do that on the workstation from which
# the Cog image is being built. It can then be injected into the new
# Cog image.

# First, we need to determine which cogctl image we're going to
# use. If we've built a release of cogctl, there will be a container
# tagged using the Git tag of that release. Cog and cogctl will both
# share this tag. Thus, if Cog is being built from a tag, then we
# should pull down the corresponding cogctl image.
#
# If it is not being built from a tag, however, we should just pull
# down the current "master" tag from the cogctl repository.
#
# Since we only build Cog images on Alpine Linux at the moment, we
# always pull the Alpine image for cogctl.
#
# (Note: the following code is similar to code used for relay and
# cogctl builds.)
tag=`git describe --tags`
dash_count=`git describe --tags | grep -o - | wc -l | sed "s/ //g"`
if [ "$dash_count" == "0" ]
then
    # We're directly on a tag
    image="operable/cogctl:alpine-${tag}"
else
    # We're not right on a tag, so just grab the master image
    image="operable/cogctl:alpine-master"
fi

# Actually pull the image
docker pull "${image}"

# Extract the executable to the local filesystem. The name of the
# extracted file will be "cogctl-for-docker-build".
container_id=$(docker create "${image}")
docker cp "${container_id}:/usr/bin/cogctl" cogctl-for-docker-build
docker rm "${container_id}"
