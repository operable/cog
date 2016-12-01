# Development Guide

[![Build status](https://badge.buildkite.com/ce01baf77e07a728f3d80575254634c3d63d8a5eda69ba7fb3.svg?branch=master)](https://buildkite.com/operable/cog)

## Local Setup

Cog depends on a few things to run locally:

    * Postgres (9.4+)
    * A `SLACK_API_TOKEN` environment variable (with a valid token)

With those installed, setup your computer with:

    $ mix cog.setup

## Run Cog

    $ make run

Cog will be run on `http://localhost:4000`.

## Notes on Relay

If you are running cog with relay, which you probably should be, note that this
version of cog does not work with the old elixir based relay. To use relay use
the new go based version, (https://github.com/operable/go-relay)

## Testing

Preliminary database setup:

    $ MIX_ENV=test make reset-db

Unit Tests:

    $ make test-unit

Pipeline Integration Tests:

    $ make test-integration

Slack Integration Tests

    $ make test-slack

Hipchat Integration Tests

    $ make test-hipchat

Slack and HipChat tests require credentials provided as environment variables. See the `SLACK_*` and `HIPCHAT_*` variables, respectively, in [The Cog Book](https://cog-book.operable.io/#_cog_server_configuration)


HTTP requests in integration tests are recorded and stubbed out for future test
runs. Recording new cassettes, json files of serialized requests and responses,
happens automatically when using the `Cog.VCR.use_cassette` macro. To
regenerate these stubs by making actual HTTP requests delete the files you wish
to regenerate and run the tests.
