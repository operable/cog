# Release Notes

## v0.3

- Existing command bundles will need to migrate their config.json files to YAML. See [here](https://github.com/operable/cog/wiki/Building-Command-Bundles) for details.
- Existing Cog installations can be upgraded to 0.3 with the following steps:
  1. Backup Cog's database.
  1. Compile a list of the following information:
    - User accounts and their permissions, groups & role memberships
    - Installed command bundles
  1. Using Cog 0.3 run `make reset-db`. This will drop & recreate the Postgres
  schema and re-run schema migrations.
  1. Manually re-create the users noted in step #2.
  1. Verify previously installed bundles are enabled via `cogctl`.
