#!/usr/bin/env bash

set -eu

export MIX_ENV="test"

echo "Waiting for Postgres to become available..."
./scripts/wait-for-it.sh -s -t 0 -h "postgres" -p "5432" && true

echo "Apply database migrations..."
mix ecto.migrate --no-deps-check

echo "Running Slack tests..."
mix test --only=slack

