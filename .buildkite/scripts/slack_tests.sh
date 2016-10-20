#!/usr/bin/env bash

set -eu

.buildkite/scripts/wait_for_postgres.sh && \
  MIX_ENV=test mix do ecto.reset --no-start, test --only=slack

