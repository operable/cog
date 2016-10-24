#!/usr/bin/env bash

# For running tests in buildkite using Docker containers

set -eu

export MIX_ENV="test"

# Time to wait for the database to come up in seconds
DB_TIMEOUT=30

run_migrations()
{
  echo "Apply database migrations..."
  mix ecto.migrate --no-deps-check
}

run_tests()
{
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
}

# When Postgres comes up we can run our migrations and the test
echo "Waiting for Postgres to become available..."
if $(./scripts/wait-for-it.sh -s -t $DB_TIMEOUT -h "postgres" -p "5432" -- true); then
  run_migrations;
  run_tests $1;
fi

