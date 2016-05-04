#  Changelog

## v0.5.0

### Enhancements

- [Memory Service for Commands](http://docs.operable.io/v0.5/docs/services)
- [Relay and relay group administrative commands](https://github.com/operable/cog/issues/513)
- [ChatOps Design Guide](http://docs.operable.io/v0.5/docs/designing-for-chatops)
- [Create superuser role during bootstrap](https://github.com/operable/cog/issues/360)
- [Added --enable flag to cogctl relays create](https://github.com/operable/cog/issues/566)
- [Improved cogctl's option parsing abilities](https://github.com/operable/cog/issues/578)

### Bug Fixes

- Clean up cogctl output (546)[https://github.com/operable/cog/issues/546]
- Fixed error when creating relay group with members (567)[https://github.com/operable/cog/issues/567]
- Bootstrap should be idempotent (574)[https://github.com/operable/cog/issues/574]
- Command parser errors on strings containing '.' (584)[https://github.com/operable/cog/issues/584]

## v0.4.1

### Enhancements

- [Enforce enabled/disabled state for Relays](https://github.com/operable/cog/pull/572)

### Bug Fixes

- [Fix environment generation for non-string command options](https://github.com/operable/go-relay/pull/5)
- [Increase timeout for external HTTP requests to handle slow chat provider API calls](https://github.com/operable/cog/pull/579)

## v.0.4.0

### Enhancements

- Pipeline Triggers
  - Process external events with command pipelines
  - Flexible output routing
  - Audit log integration
- Brand new Relay written in Go
  - Easier to deploy & configure
  - Replaces previous Relay written in Elixir
- Docker integration
  - Distributed command bundles as Docker images
  - Commands executed inside isolated containers
  - Built-in support for public and private remote registries
- Revised bundle format and deployment process
  - Simplified bundle deployment process -- upload a single file
  - Deploy a bundle to groups of Relays
  - Supported bundle types:
    - Simple
    - Docker
    - Zip file command bundle support EOL'd
  - Simplified bundle config file w/sane defaults
- All new documentation site: http://docs.operable.io
  - GitHub wiki deprecated

### Bug Fixes

- [Prevent users from creating aliases with fully qualified names](https://github.com/operable/cog/issues/314)
- [Slack Real Time Messaging connector crashes on API timeouts](https://github.com/operable/cog/issues/479)
- [Ensure pipeline executor permission checks can see all user permissions](https://github.com/operable/cog/issues/496)
- [Protect admin group, admin role, and built-in permissions from modification](https://github.com/operable/cog/issues/543)

## v0.3.0

### Enhancements

- SSL support for Cog <-> Relay communication
- Unix-style command & pipeline aliases
- All new command pipeline execution subsystem
  - Supports nested variable references: `$instances[0].tags[1]`
  - Improved pipeline execution error messages
  - Removes a number of ugly hacks to handle pipeline execution edge cases
- Simplified installation
  - Removed dirty scheduler and SMP support requirement
  - Spoken command configuration controlled by environment variable
  - HipChat config support added to Docker compose file
- Better error messages
  - Chat adapters aggressively verify their configuration before starting
  - Cog tells unknown users why they are being ignored
- Improved chat command development experience
  - Migrated to YAML for command bundle configuration (inspired by Josh Nichols)
  - Consolidated and simplified command execution model
- JSON path navigation added to `filter` command
- Experimental IRC adapter (pull requests welcome!)
- Make user first and last name optional when adding new users

### Bug Fixes

- Handle Slack-escaped URLs and smart quotes
- Removed old chat adapters from database migrations
- Fixed column ordering bug in `table` command (reported by James Bowes)
- Route command log output to Relay log file
- Improved handling of unexpected command crashes
- Multiple bugs in `mist` command bundle (reported by Adam Ochonicki)
- Stopped sending Slack UID to users (reported by Adam Ochonicki)
- Improved output handling of `multi` commands when called at the end of a pipeline

### Documentation

- Documented Cog's permission rule language
- Wiki typo fixes (reported by Jordan Sissel)
