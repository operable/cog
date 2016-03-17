#  Changelog

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
