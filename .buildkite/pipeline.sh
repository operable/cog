#!/bin/bash

set -euo pipefail

# Time to wait for the database to come up in seconds
DB_TIMEOUT=30


cat <<EOF
steps:
  - label: ":docker: Build Test Image"
    plugins:
      docker-compose:
        build: test
        image_repository: "index.docker.io/operable/cog-testing"
        config: docker-compose.ci.yml

  - wait
EOF

########################################################################
# Self-contained Tests

for TEST in unit integration
do
cat <<EOF

  - command: ./scripts/wait-for-it.sh postgres:5432 -s -t ${DB_TIMEOUT} -- make test-${TEST}
    label: ":cogops: ${TEST}"
    plugins:
      docker-compose:
        run: test
        config: docker-compose.ci.yml
EOF
done

########################################################################
# Live Chat Provider Tests

for PLATFORM in slack hipchat
do
cat <<EOF

  - command: ./scripts/wait-for-it.sh postgres:5432 -s -t ${DB_TIMEOUT} -- make test-${PLATFORM}
    label: ":${PLATFORM}: Integration"
    plugins:
      docker-compose:
        run: test
        config: docker-compose.ci.yml
    concurrency_group: "cog_${PLATFORM}_integration"
    concurrency: 1
EOF
done

########################################################################
# "Real" Image build
#
# The docker-compose image above is for a testing build of Cog, not
# for the real images we ultimately distribute. In the future, we may
# converge the two, but for now, we'll build the real images
# separately. This'll allow us to provide up-to-date images if we so
# choose, as well as easily provide images to dependent pipelines
# (like the cogctl we trigger below).
#
# When / if Buildkite gets a plain Docker plugin (as opposed to the
# docker-compose one), we might be able to replace some of this custom
# code.)

# Not sure if both build number and commit SHA is overkill here or
# not. Both are probably useful right now; build number can help us
# (Operable) track things down, but commit provides extra clarity (and
# can be meaningfully used by non-Operable folks until Buildkite opens
# up builds for public view).
#
#
# For now, we'll push this to `cog-testing`, instead of `cog`, even
# though it's a "real" image. Once we start actually promoting
# official images from CI, though, we can send it to `cog`.
COG_IMAGE="operable/cog-testing:ci-build-${BUILDKITE_BUILD_NUMBER}-${BUILDKITE_COMMIT::8}"

cat <<EOF

  - wait

  - command: .buildkite/scripts/build_and_push_docker_image.sh $COG_IMAGE
    label: ":docker: Build Real Image"

  - wait
EOF

########################################################################
# Triggered Builds

# If there's a branch in cogctl with the same name as the branch we're
# building here in Cog, use that branch. Otherwise, build on master.
if git ls-remote --exit-code --heads https://github.com/operable/cogctl refs/heads/${BUILDKITE_BRANCH} > /dev/null 2>&1
then
    TRIGGER_BRANCH=${BUILDKITE_BRANCH}
else
    TRIGGER_BRANCH='master'
fi

cat <<EOF

  - trigger: "cogctl"
    label: ":cogops: Triggered cogctl build"
    async: true
    build:
      branch: "${TRIGGER_BRANCH}"
      commit: "HEAD"
      env:
        COG_IMAGE: ${COG_IMAGE}
EOF
