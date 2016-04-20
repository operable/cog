# Development Guide

[![Build status](https://badge.buildkite.com/ce01baf77e07a728f3d80575254634c3d63d8a5eda69ba7fb3.svg?branch=master)](https://buildkite.com/operable/cog)

## Local Setup

Cog depends on a few things to run locally:

    * Postgres
    * A `SLACK_API_TOKEN` environment variable (with a valid token)

With those installed, setup your computer with:

    $ make setup

## Run Cog

    $ make run

Cog will be run on `http://localhost:4000`.

## Notes on Relay

If you are running cog with relay, which you probably should be, note that this
version of cog does not work with the old elixir based relay. To use relay use
the new go based version, (https://github.com/operable/go-relay)

## Testing

    $ make test

HTTP requests in integration tests are recorded and stubbed out for future test
runs. Recording new cassettes, json files of serialized requests and responses,
happens automatically when using the `Cog.VCR.use_cassette` macro. To
regenerate these stubs by making actual HTTP requests delete the files you wish
to regenerate and run the tests.

For instance, to update all tests you could run this:

    $ rm test/fixtures/cassettes/* && make test

Just make sure you have the `TEST_SLACK=1` and `TEST_HIPCHAT=1`
environment variables set.
