#  Changelog

## 1.0.0-beta.3

### Enhancements
* Complete rewrite of cogctl in Python
* Support Slack Thread responses [#1312](https://github.com/operable/cog/pull/1312)
* Fail more gracefully when SMTP isn't configured properly [#1353](https://github.com/operable/cog/issues/1353)
* Protect pipeline history and kill commands with permission checks [#1327](https://github.com/operable/cog/issues/1327)

### Bug Fixes
* operable:pipeline-list and operable:pipeline-history fail if chat username != cog username [#1334](https://github.com/operable/cog/issues/1334)
* group command does not return associated users [#1332](https://github.com/operable/cog/issues/1332)
* Parsing history index ranges fails [#1337](https://github.com/operable/cog/issues/1337)
* Catch constraint errors on role delete [#1344](https://github.com/operable/cog/issues/1344)
* Executor crashes when command aborts [#1340](https://github.com/operable/cog/issues/1340)
* Apply constraints when deleting relay groups [#1349](https://github.com/operable/cog/issues/1349)
* Event log timestamps are not valid ISO8601. [#1350](https://github.com/operable/cog/issues/1350)
* Parsing escaped quotes in json fails in the `seed` command [#1323](https://github.com/operable/cog/issues/1323)
* `history -l 1` crashes [#1364](https://github.com/operable/cog/issues/1364)
* Gracefully handle failure when assigning a chat handle to more than one user [#1366](https://github.com/operable/cog/issues/1366)

## 1.0.0-beta.2

### Enhancements

* Add output documentation for commands [#1224](https://github.com/operable/cog/pull/1224)
* "Git-style" embedded bundle commands [#1206](https://github.com/operable/cog/issues/1206),
* Increase timestamp resolution for events [#1253](https://github.com/operable/cog/issues/1253)
* Create a `trigger-update` template [#1241](https://github.com/operable/cog/issues/1241)
* Drop Mustache support [#1261](https://github.com/operable/cog/pull/1261)
* Modify event log format to be friendlier to log aggregators [#1255](https://github.com/operable/cog/issues/1255)
* Explicitly refuse to run unsupported bundles [#1262](https://github.com/operable/cog/issues/1262)
* Improve list templates and fix failing tests due to bugfixes [#1277](https://github.com/operable/cog/pull/1277)
* Share MQTT connections between processes [#1287](https://github.com/operable/cog/pull/1287)
* Add `info` command to display information about the currently running Cog [#1284](https://github.com/operable/cog/issues/1284)
* Remove subcommand documentation from commands in bundle config [#1204](https://github.com/operable/cog/issues/1204)
* Apply snappy compression to all message bus traffic [#874](https://github.com/operable/cog/issues/874)
* Support "all" operator in rule clauses that refer to list types. [#1209](https://github.com/operable/cog/issues/1209)
* Update to docker-compose v2 syntax [#1307](https://github.com/operable/cog/issues/1307)
* Modernize pipeline execution [#1310](https://github.com/operable/cog/issues/1310)
* Protect the last user in the cog-admin group [#1309](https://github.com/operable/cog/pull/1309)
* Added pipeline management commands [#1320](https://github.com/operable/cog/pull/1320)

### Bug Fixes
* Interpolated strings cannot be part of a list-valued option [#1221](https://github.com/operable/cog/issues/1221)
* Trigger list template incorrectly renders pipelines that are actually pipelines [#1239](https://github.com/operable/cog/issues/1239)
* Aborting commands is confusing with triggers [#1243](https://github.com/operable/cog/issues/1243)
* Users without last names cannot execute triggers! [#1245](https://github.com/operable/cog/issues/1245)
* Trigger users need to have referential integrity [#1246](https://github.com/operable/cog/issues/1246)
* Ignore bare `!` messages [#1187](https://github.com/operable/cog/issues/1187)
* Aborting a command crashes the executor [#1296](https://github.com/operable/cog/issues/1296)
* cogctl can generate broken profiles on startup [#1301](https://github.com/operable/cog/issues/1301)

  Applies to the `.cogctl` file generated inside the `cog` Docker container.
* Crash when executing a command assigned to a relay group with no running relays [#1314](https://github.com/operable/cog/issues/1314)
* Connection failure crashes Slack provider [#1317](https://github.com/operable/cog/issues/1317)

### Documentation
* Cleaned up documentation for `docker compose` usage [#1273](https://github.com/operable/cog/pull/1273/)

## 1.0.0-beta.1

### Enhancements

- First release of `gbexec` [#952](https://github.com/operable/cog/issues/952)
- Added support for Markdown links in Greenbar templates [#1076](https://github.com/operable/cog/issues/1076)
- Relay reopens log files on `SIGHUP` [#1126](https://github.com/operable/cog/issues/1126)
- Streamlined Cog's URL generation [#1139](https://github.com/operable/cog/issues/1139), [#1158](https://github.com/operable/cog/issues/1158)
- Made global error template user customizable [#1142](https://github.com/operable/cog/issues/1142)
- Default managed dynamic config to enabled; Automatically downcase Relay UUIDs [#1147](https://github.com/operable/cog/issues/1147)
- Expose user email to command invocation environment variables [#1152](https://github.com/operable/cog/issues/1152)
- Improved HipChat attachment rendering [#1182](https://github.com/operable/cog/issues/1182)
- Made history token user configurable [#1184](https://github.com/operable/cog/issues/1184)
- Unified HipChat and Slack table rendering [#1186](https://github.com/operable/cog/issues/1186)
- Added Markdown paragraph support to Greenbar [#1200](https://github.com/operable/cog/issues/1200)

### Bug Fixes

- Updated role API to handle role revocation failures [#825](https://github.com/operable/cog/issues/825)
- Re-added Relay support for per-command environment variables [#1143](https://github.com/operable/cog/issues/1143)
- Command parsing fails when extended Unicode characters are followed by a URL [#1161](https://github.com/operable/cog/issues/1161)
- History command (defaults to `!!`) crashes when not used with @-style mention [#1179](https://github.com/operable/cog/issues/1179)
- Improved error message visibility in stock error template [#1183](https://github.com/operable/cog/issues/1183)
- Empty command output section visible in command help [#1223](https://github.com/operable/cog/issues/1223)

### Documentation

- Added command execution environment [#953](https://github.com/operable/cog/issues/953), [#1207](https://github.com/operable/cog/issues/1207)
- Added Greenbar tempate engine [#1188](https://github.com/operable/cog/issues/1188)


## 0.16.2

### Enhancements

- Allow `help` command to work with non-qualified command names [#1109](https://github.com/operable/cog/issues/1109)
- Allow bootstrapping to set a chat handle [#1226](https://github.com/operable/cog/issues/1226)

### Bug Fixes

- Invalid bundle config file shouldn't cause `cogctl` to fall back to install from [Bundle Warehouse](https://bundles.operable.io) [#1137](https://github.com/operable/cog/issues/1137)
- `greenbar` segfaults processing nested triple ticks [#1141](https://github.com/operable/cog/issues/1141) (Reported by @agis-)
- Cog eventually becomes unresponsive on Slack [#1153](https://github.com/operable/cog/issues/1153) (Reported by @agis-)
- `operable:group -h` crashes [#1154](https://github.com/operable/cog/issues/1154)
- Uninstalled bundles can be listed as disabled [#1155](https://github.com/operable/cog/issues/1155)
- Piping a command alias into other commands or aliases fails [#1166](https://github.com/operable/cog/issues/1166)

## 0.16.1

### Bug Fixes

- Command parser mangles Unicode inputs [#1133](https://github.com/operable/cog/issues/1133)
- String interpolation breaks variable references in aliases [#1135](https://github.com/operable/cog/issues/1135)
- Relay can't log to a file [#1123](https://github.com/operable/cog/issues/1123)
- Ensure `SetAvailable` is run for all engine types [PR](https://github.com/operable/go-relay/pull/47) (Thanks @ctrochalakis!)
- Removed references to `cog-relay` in Relay's `README.md` [PR](https://github.com/operable/cog-relay/pull/45) (Thanks @0xdiba!)

## 0.16.0

### Enhancements

- Brand new command parser [#1082](https://github.com/operable/cog/issues/1082)
  - Supports string interpolation `"EC2 Region ${region}"`
  - Improved shell-like behavior greatly reduces surprising parse errors
- Added support for git-style subcommands [#1091](https://github.com/operable/cog/issues/1091)
- Added basic usage tracking [Pull Request](https://github.com/operable/cog/pull/1104)
  - This information is used by Operable in order to help understand the size of the Cog install
    base and the currently deployed versions. If you would like to opt out of having this telemetry data
    sent, you can set the `COG_TELEMETRY` environment variable to the value false before starting Cog.
- Added `tee` and `cat` commands [Pull Request](https://github.com/operable/cog/pull/1101)
- Allow binding JSON arrays to list options [#1097](https://github.com/operable/cog/issues/1097)
- Added support for single and triple backticks to Greenbar templates [#1087](https://github.com/operable/cog/issues/1087)
- Improved `command not found` error messages [#1092](https://github.com/operable/cog/issues/1092)
- Made timeouts configurable for interactive and trigger pipelines [#1027](https://github.com/operable/cog/issues/1027)
- Moved to Erlang R19.1 and Elixir 1.3.4 [#1028](https://github.com/operable/cog/issues/1028)
- Deprecated `mist` bundle replaced with `ec2` and `s3` bundles [#1051](https://github.com/operable/cog/issues/1051)
- Added health checks to `docker-compose.yml` [#939](https://github.com/operable/cog/issues/939)

### Bug Fixes

- Raw commands should return JSON [#1023](https://github.com/operable/cog/issues/1023)
- Bundle install can return an incorrect error message [#1065](https://github.com/operable/cog/issues/1065)
- Greenbar interprets `!=` as `==` [#1071](https://github.com/operable/cog/issues/1071)
- Triggers should be able to redirect to newly created rooms [#1096](https://github.com/operable/cog/issues/1096)
- Cannot interact with HipChat room names containing a space [#1102](https://github.com/operable/cog/issues/1102)
- Slack @-mentions aren't properly linkified [#1111](https://github.com/operable/cog/issues/1111)
- Required options don't work w/short option names [#1088](https://github.com/operable/cog/issues/1088)
- Fixed password reset emails [Pull Request](https://github.com/operable/cog/pull/1114)
- Fixed permission rule evaluation for list options [Pull Request](https://github.com/operable/cog/pull/1077)

### Documentation

- Documented `docker-compose-override.yaml` [#961](https://github.com/operable/cog/issues/961)

## 0.15.2
### Bug Fixes

- Local Relays connecting prior to registration crash Cog [#1034](https://github.com/operable/cog/issues/1034)
- Chat handle creation erroneous error [#1049](https://github.com/operable/cog/issues/1049)
- Relay suffers from frequent disconnects [#1050](https://github.com/operable/cog/issues/1050)
- Bot does not respond to HipChat DMs [#1053](https://github.com/operable/cog/issues/1053)
- Bump the embedded bundle version [#1063](https://github.com/operable/cog/issues/1063)
- Enable dynamic config for Relay in container [#1066](https://github.com/operable/cog/issues/1066)

## 0.15.1

### Bug Fixes

- Removed `COG_HIPCHAT_ENABLED` and `COG_SLACK_ENABLED` from base `docker-compose.yml` [#1037](https://github.com/operable/cog/issues/1037)

## 0.15.0

### Enhancements

- Restored HipChat support [#968](https://github.com/operable/cog/issues/968)
- Added global switch to toggle access rule enforcment [#977](https://github.com/operable/cog/issues/977)
- Added a `--force` flag to cogctl for bundle installations [##969](https://github.com/operable/cog/issues/969)
- Added an optional "config" section to bundle help [#948](https://github.com/operable/cog/issues/948)
- Allowed bundle installs from [Warehouse](https://bundles.operable.io) [#988](https://github.com/operable/cog/pull/988)
- Validate Slack bot tokens during startup [#1021](https://github.com/operable/cog/issues/1021)
- Documented SMTP and password reset environment variables [#910](https://github.com/operable/issues/910)
- Improved cogctl documentation [#930](https://github.com/operable/issues/930)

### Bug Fixes

- cogctl uses the "old" style templates when generating bundle configs for installation [#1000](https://github.com/operable/cog/issues/1000)
- Cog should use user id references when responding to users [#944](https://github.com/operable/cog/issues/944)
- Allow Piper to handle datum dot datum/string as an argument or option value [#1015](https://github.com/operable/cog/issues/1015)
- Removed re-execution of edited commands from Cog [#1013](https://github.com/operable/cog/issues/1013)

## 0.14.1

### Bug Fixes

- Relay left in zombie state when partially disconnected [#990](https://github.com/operable/cog/issues/990)
  - Relay now halts whenever one of its message bus connections is lost. Users will need to ensure that Relay is properly run under supervision.
- Support groups (private channels and group DMs) in the Slack adapter [#973](https://github.com/operable/cog/issues/973)
  - A regression occurred when we rewrote the Slack chat adapter; Cog can once again interact with private channels
- Fix how redirects are specified [#976](https://github.com/operable/cog/issues/976)
  - Another regression with the new Slack chat adapter was fixed; redirects work again in Slack
- Can't log from commands at anything but INFO levels [#980](https://github.com/operable/cog/issues/980)
- Echo command crashes with non-string args [#981](https://github.com/operable/cog/issues/981)
- Cog crashes processing slackbot messages [#982](https://github.com/operable/cog/issues/982)
- values in json objects can only be referenced one level deep with the dot syntax [#993](https://github.com/operable/cog/issues/993)
- Relay doesn't consider developer mode at startup [#997](https://github.com/operable/cog/issues/997)
- Aborted commands crash the executor [#1003](https://github.com/operable/cog/issues/1003)
- Unordered lists render incorrectly in Slack [#1004](https://github.com/operable/cog/issues/1004)

## 0.14.0

### Enhancements

- New Template Engine [#876](https://github.com/operable/cog/issues/876)

  - Cog's previous Mustache-based template engine, [fumanchu](https://github.com/operable/fumanchu), has been deprecated and replaced
    by [greenbar](https://github.com/operable/greenbar). The combination of Cog's new chat API (released in 0.13) and Greenbar allows
    Cog to render a single template across multiple providers and preserve the majority of formatting.

- Added a `-dev` flag to Relay's CLI [#950](https://github.com/operable/cog/issues/950)

  - We've added a development mode to Relay to simplify bundle development. Starting a Relay with `-dev` causes Relay to
    re-pull any Docker images associated with installed command bundles on each pipeline execution. This should simplify
    iterating command development.

- Improved presentation of bundle and command help [#658](https://github.com/operable/cog/issues/658)

- Introduced new bundle config version 4 which adds documentation structure
  used by help command and reorganized template definitions. Also bundle
  descriptions are now required. [spanner #76](https://github.com/operable/spanner/pull/76/files)

### Bug Fixes

- Return better error message for invalid dynamic configurations [#867](https://github.com/operable/cog/issues/867)
- Update Docker installation documentation [#932](https://github.com/operable/cog/issues/932)
- Documented Relay's backoff & retry behavior when disconnected [#935](https://github.com/operable/cog/issues/935)


## 0.13.0

### Enhancements

- New chat API [#873](https://github.com/operable/cog/issues/873), [#925](https://github.com/operable/cog/issues/925)

  - The API Cog uses to interop with various chat networks has been thoroughly revamped. A temporary side-effect of this work
    is the removal of HipChat and IRC support. We expect to restore support for both of these chat networks in an upcoming
    release.

- Expose room/channel name to commands [#914](https://github.com/operable/cog/issues/914) (requested by Tu Hoang)
- Improve handling of list option types [#919](https://github.com/operable/cog/issues/919)
- Reset passwords via cogctl [#894](https://github.com/operable/cog/issues/894), [#907](https://github.com/operable/cog/issues/907)
- Update stale dependencies [#864](https://github.com/operable/cog/issues/864)

### Bug Fixes

- $PATH lost to standard bundles [#839](https://github.com/operable/cog/issues/839) (reported by George Adams)
- Access rule evaluation crashes on rules using option values with "in" [#918](https://github.com/operable/cog/issues/918)
- Chat pipeline evaluation crashes on non-scalar variable bindings [#916](https://github.com/operable/cog/issues/916)

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
