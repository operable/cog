#!/usr/bin/env bash

# For running tests in buildkite using Docker containers

set -eu

export MIX_ENV="test"

# First we wait for the Postgres container to become available
# NOTE: The wait-for-it scripts expects a different 'timeout' command
# than is installed in Alpine linux. So we set the timeout to 0 and
# explicitly call the timeout command used by Alpine linux.
echo "Waiting for Postgres to become available..."
if [ ! $(timeout -t 30 ./scripts/wait-for-it.sh -s -t 0 -h "postgres" -p "5432") ]; then
  echo "Timeout waiting for Postgres to start.";
  exit 1;
fi

# Then we migrate the db
echo "Apply database migrations..."
mix ecto.migrate --no-deps-check

# Finally we run our tests
case $1 in
  unit )
    echo "Running Unit tests...";
    mix test --exclude=integration;;
  slack )
    echo "Running Slack tests...";
    mix test --only=slack;;
  hipchat )
    echo "Running HipChat tests...";
    mix test --only=hipchat;;
  * )
    echo "Running tests...";
    mix test;;
esac
