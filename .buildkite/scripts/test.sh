#!/usr/bin/env bash

# For running tests in buildkite using Docker containers

set -eu

# Time to wait for the database to come up in seconds
DB_TIMEOUT=30

run_tests()
{
  case $1 in
    unit )
      echo "Running Unit tests...";
      make test-unit;;
    integration )
      echo "Running general integration tests...";
      make test-integration;;
    slack )
      echo "Running Slack tests...";
      make test-slack;;
    hipchat )
      echo "Running HipChat tests...";
      make test-hipchat;;
    * )
      echo "Unrecognized test: $1"
      exit 1;;
  esac
}

# When Postgres comes up we can run our migrations and the test
echo "Waiting for Postgres to become available..."
if $(./scripts/wait-for-it.sh -s -t $DB_TIMEOUT -h "postgres" -p "5432" -- true); then
  run_tests $1;
fi
