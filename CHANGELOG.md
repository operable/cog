#  Changelog

## 0.12.0

### Enhancements

- Support for per-room and per-user dynamic configuration [#850](https://github.com/operable/cog/issues/850)
- Updated message bus to emqttd 1.1.2 [#865](https://github.com/operable/cog/issues/865)

### Bug Fixes

- Fixed several bugs around Cog's management of emqttd [#897](https://github.com/operable/cog/issues/897)
- Fixed nil pointer error in Relay [#885](https://github.com/operable/cog/issues/885)

## 0.11.0

### Enhancements

- Sign ups for the Hosted Cog beta test have [opened] (http://bit.ly/29OTR39).
- Mount user-defined directories into commands' Docker containers [#838](https://github.com/operable/cog/issues/838) (requested by George Adams)
- Use override file to customize Cog's docker-compose configuration [#843](https://github.com/operable/cog/pull/843) (contributed by Brian Stolz)

### Bug Fixes

- Restore `cogctl`'s SSL support [#853](https://github.com/operable/cog/issues/853)
- Substring match to detect bot mentions can yield false positives [#855](https://github.com/operable/cog/issues/855)
- Hangs encountered when managed dynamic configuration is enabled [#861](https://github.com/operable/cog/issues/861)

## 0.10.0

### Enhancements

- Automatically create Cog accounts for new users [#277](https://github.com/operable/cog/issues/277) (Slack only)
- Commands can abort pipelines and return simple errors [#691](https://github.com/operable/cog/issues/691)
  - Released [pycog3 v0.1.27](https://pypi.python.org/pypi/pycog3/0.1.27)
  - Released [cog-rb v.0.1.8](https://rubygems.org/gems/cog-rb/versions/0.1.8)
- Eliminate spammy log messages in Cog's console [#841](https://github.com/operable/cog/issues/841)
- `format:table` now supports field names and paths to fields [#784](https://github.com/operable/cog/issues/784)

## 0.9.1

### Bug Fixes

- Properly handle command execution errors [#836](https://github.com/operable/cog/issues/836)

## 0.9.0

### Enhancements

- Automatically bootstrap Cog install via environment variables [#811](https://github.com/operable/cog/pull/811)
- Add `operable:user` command [#147](https://github.com/operable/cog/issues/147)
- Add `operable:chat-handles` command [#787](https://github.com/operable/cog/issues/787)
- Add `list`, `info`, and `versions` subcommands to `operable:bundle` chat command [#776](https://github.com/operable/cog/issues/776)
- Redesign `operable:permissions` and `operable:role` command [#675](https://github.com/operable/cog/issues/675), [#678](https://github.com/operable/cog/issues/678)
- Cache Relay for a given bundle during pipeline execution [#777](https://github.com/operable/cog/issues/777)
- Improve Relay's command encoding scheme [#837](https://github.com/operable/cog/issues/837)
- Unify chat naming conventions [#681](https://github.com/operable/cog/issues/681)
- Reserve "cog" bundle name for future use [#817](https://github.com/operable/cog/issues/817)

### Bug Fixes

- Remove single trailing newline from template source [#835](https://github.com/operable/cog/issues/835)
- Prevent revoking `cog-admin` role from the `cog-admin` group [#795](https://github.com/operable/cog/issues/795)
- Relay bundle catalog diff misses removed bundles [#791](https://github.com/operable/cog/issues/791)
- Clean up pre-bundle versions database tables [#783](https://github.com/operable/cog/issues/783)

## 0.8.0

### Enhancements

- Added `operable:trigger` chat command [#771](https://github.com/operable/cog/issues/771)
- `cogctl` can read `config.yaml` from stdin [#773](https://github.com/operable/cog/issues/773)
- Incident Response workflow [#698](https://github.com/operable/cog/issues/698)
- Added support for configurable container memory in Relay [docs](http://docs.operable.io/v0.8/docs/relay-environment-variables)

### Command bundles

- `pagerduty` _NEW_
  - Repo: [cogcmd/pagerduty](https://github.com/cogcmd/pagerduty)
- `pingdom` _NEW_
  - Repo: [cogcmd/pingdom](https://github.com/cogcmd/pingdom)

### Bug Fixes

- Multi commands run slowly [#677](https://github.com/operable/cog/issues/677)
  - Optimized Relay's Docker integration:
    - Containers are cached and reused for the duration of a command
      pipeline. Doing so reduces worst case Docker container creation
      from O(N * I * R) to O(N * R) where N is the number of pipeline
      stages, I is the number of command invocations per stage, and R
      is the number of Relays able to run the command.
    - Implemented a custom streaming interface on top of Docker's
      hijacked connection API further reducing the number of Docker
      API calls required per command invocation.
  - Internal testing has shown these optimizations reduce execution
    times for Docker-based commands by 50 - 70%.
- Fix Relay's JSON handling: Don't coerce large integers into
  scientific notation [#768](https://github.com/operable/cog/issues/768)
- HipChat can't execute Relay-mediated commands [#770](https://github.com/operable/cog/issues/770)

## v0.7.5

### Enhancements

- First release of [cog-rb](https://github.com/operable/cog-rb): Ruby Cog command development library
- First release of [pycog3](https://github.com/operable/pycog3): Python3 Cog command development library

### Command bundles

- `circle` _NEW_
  - Repo: [cogcmd/circle](https://github.com/cogcmd/circle)
- `format` _NEW_
  - Repo: [cogcmd/format](https://github.com/cogcmd/format)
  - Docker image: [cogcmd/format](https://hub.docker.com/r/cogcmd/format/)
- `statuspage` _NEW_
  - Repo: [cogcmd/statuspage](https://github.com/cogcmd/statuspage)
  - Docker image: [cogcmd/statuspage](https://hub.docker.com/r/cogcmd/statuspage/)
- `twitter` bundle _NEW_
  - Repo: [cogcmd/twitter](https://github.com/cogcmd/twitter)
  - Docker image: [cogcmd/twitter](https://hub.docker.com/r/cogcmd/twitter/)

### Bug Fixes

- Command pipeline executor crashes when failing to authorized against
  a rule mentioning multiple permissions [#758](https://github.com/operable/cog/issues/758)
- go-relay doesn't respect documented calling convention [#765](https://github.com/operable/cog/issues/765)

## v0.7.0

### Enhancements

- Command Bundle Versioning w/upgrade and downgrade support [#635](https://github.com/operable/cog/issues/635),[#636](https://github.com/operable/cog/issues/636), [#637](https://github.com/operable/cog/issues/637), [#638](https://github.com/operable/cog/issues/638), [#642](https://github.com/operable/cog/issues/642), [#644](https://github.com/operable/cog/issues/644), [#657](https://github.com/operable/cog/issues/657), [#706](https://github.com/operable/cog/issues/706)
- Redesigned UX of 'group', 'rules', and 'help' commands [#671](https://github.com/operable/cog/issues/671), [#680](https://github.com/operable/cog/issues/680), [#672](https://github.com/operable/cog/issues/672)
- Auto-upgrade embedded commands when running Cog in dev mode [#721](https://github.com/operable/cog/issues/721)
- Log warning message when potentially exceeding chat provider's max message size [#739](https://github.com/operable/cog/issues/739)

### Bug Fixes

- Fixed incorrect YAML prelude in `my_bundle.yaml` [#718](https://github.com/operable/cog/issues/718) (reported by Tom Bortels)
- Allow administrators to override service and trigger base URLs [#694](https://github.com/operable/cog/issues/694)

## v0.6.0

### Enhancements

- Simplified Command Calling Convention [#399](https://github.com/operable/cog/issues/399), [#612](https://github.com/operable/cog/issues/612), [#622](https://github.com/operable/cog/issues/622), [#623](https://github.com/operable/cog/issues/623), [#624](https://github.com/operable/cog/issues/624), [#625](https://github.com/operable/cog/issues/625)
- Implemented [Designing For ChatOps](http://docs.operable.io/v0.6/docs/designing-for-chatops) guidelines [#673](https://github.com/operable/cog/issues/673), [#674](https://github.com/operable/cog/issues/674), [#687](https://github.com/operable/cog/issues/687)

### Bug Fixes

- cogctl crashes on mistyped subcommands [#685](https://github.com/operable/cog/issues/685)
- Cog can't redirect output to rooms where the invoking user isn't present [#676](https://github.com/operable/cog/issues/676) (reported by Justin Kinney)

## v0.5.0

### Enhancements

- [Memory Service for Commands](http://docs.operable.io/v0.5/docs/services)
- [Relay and relay group administrative commands](https://github.com/operable/cog/issues/513)
- [ChatOps Design Guide](http://docs.operable.io/v0.5/docs/designing-for-chatops)
- [Create superuser role during bootstrap](https://github.com/operable/cog/issues/360)
- [Added --enable flag to cogctl relays create](https://github.com/operable/cog/issues/566)
- [Improved cogctl's option parsing abilities](https://github.com/operable/cog/issues/578)

### Bug Fixes

- [Clean up cogctl output](https://github.com/operable/cog/issues/546)
- [Fixed error when creating relay group with members](https://github.com/operable/cog/issues/567)
- [Bootstrap should be idempotent](https://github.com/operable/cog/issues/574)
- [Command parser errors on strings containing '.'](https://github.com/operable/cog/issues/584)

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
