#!/bin/bash

set -euo pipefail

export DOCKER_IMAGE="$1"

echo "--- :docker: Building ${DOCKER_IMAGE}"
make docker

echo "--- :docker: Pushing ${DOCKER_IMAGE}"
docker push ${DOCKER_IMAGE}
