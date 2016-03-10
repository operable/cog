# Cog

Cog is an open chatops platform that gives you a secure, collaborative command line right in your chat window. It is designed to be secure, highly available, chat provider agnostic, and to be extensible using your favorite programming language.

![cog-demo-20](https://cloud.githubusercontent.com/assets/1198/13233523/00b9f602-d982-11e5-9177-9442e3ff54de.gif)

## Status

Cog is currently in public alpha and is not currently recommended for mission critical workflows. While many of the core features are in place, there are a number of rough edges that we anticipate smoothing out over the next few months. We are releasing it in this state in order to allow us to collaborate in the open with the community in order to build the best possible platform.

## Current Features

Below is a list of some of the current features. Cog is under heavy development and getting smarter all the time, but this list will give you an idea of some of the things that Cog knows how to do.

* **Extensibility**
  * __Build new bot commands in any language__
  * Commands return structured data to allow for creative adaptation in pipelines
  * Built in templating allows the command response to be formatted for the current chat provider without embedding markup in your logic
* **Adaptability**
  * Unix-style pipelines allow you to combine a series of simple commands to solve complex, unexpected problems
  * Support for output redirection lets you make sure everyone is in the loop
* **Security**
  * Fine-grained command permissions give you confidence in using chatops for even the most sensitive workflows
  * Users, Groups, and Roles allow you to organize access control for ease of management
  * Audit logging for commands and administrative functions let you keep track of everything that happens with Cog
* **Chat-provider agnostic**
  * Current support for Slack with an early HipChat adapter in progress

## Local Setup

Cog depends on a few things to run locally:

    * Postgres
    * A `SLACK_API_TOKEN` environment variable (with a valid token)
    * Erlang compiled with the dirty schedulers enabled
    * `libsodium`

With those installed, setup your computer with:

    $ make setup

## Run Cog

    $ make run

Cog will be run on `http://localhost:4000`.

## Resources

* [Cog Wiki](https://github.com/operable/cog/wiki)
* [GitHub Issues](https://github.com/operable/cog/issues)
* [Cog Public Chat](http://slack.operable.io/)
* [How to Contribute](https://github.com/operable/cog/blob/master/CONTRIBUTING.md)
* [Code of Conduct](https://github.com/operable/cog/blob/master/CODE_OF_CONDUCT.md)
