Cog: Operable's ChatOps Bot
==============================

## Environment Variables and You!
Cog relies on a number of environment variables for configuration.

### The Variables
#### Slack
* `SLACK_RTM_TOKEN` - token for Slack's Websocket-based [Real-Time Messaging API](https://api.slack.com/rtm)
* `SLACK_API_TOKEN` - token for Slack's [REST API](https://api.slack.com/web)
* `SLACK_API_CACHE_TTL` - Cog-specific configuration; time in seconds to cache API responses

#### Database
* `DATABASE_URL` - The database connection string URL for [Ecto](https://github.com/elixir-lang/ecto) to use. The format is `ecto://${DB_USER}:${PASSWORD}@${HOST}:${PORT}/${DB_NAME}`

### Developer Experience
#### Slack
*TODO*: Document token creation

Note: tokens are currently _not_ required for running the unit tests, as they use a ["null"](https://github.com/operable/cog/blob/master/lib/cog/adapters/null.ex) adapter.

#### Database
Using [Postgres.app](http://postgresapp.com/) is the easiest way to get started on OS X. We are currently using version [9.4.4.1](https://github.com/PostgresApp/PostgresApp/releases/tag/9.4.4.1) (see the [Releases](https://github.com/PostgresApp/PostgresApp/releases) page for specific versions).

In such a scenario, the following values will be enough to get you going:

    export DATABASE_URL="ecto://${USER}@localhost/cog"

(Note that by default, Postgres.app allows you to connect as your workstation user account without a password using the default PostgreSQL port of `5432`. As such, those values are not required in the URL.)

For example, to run the tests locally, you could run:

    DATABASE_URL="ecto://$USER@localhost/cog_test" MIX_ENV=test mix do ecto.drop, test

Using a test-specific database is nice, as it allows you to keep tests isolated from any development databases you may have running (say, `cog_dev`).

Alternatively, you can just run `make test`, which does the same thing :smiley:

#### Staging

The staging environment runs in convox, using the `cog` app. To access logs and otherwise work with the app, you'll want to download the Convox CLI from their web site and then use `convox login` with the hostname and password for our convox rack to access it.

```
$ curl http://`convox apps info cog | grep Hostname | awk '{ print $2 }'`/v1/users
{"users":[{"last_name":"Administrator","id":"1dd3e0df-61b6-4959-82c2-af32a642397b","first_name":"Cog","email_address":"admin@operable.io"}]}
```

The admin user has been created, and the generated password has been saved in the app's environment for ease of retrieval. You can find it with `convox env get ADMIN_PASSWORD --app cog`.

Other useful commands:
* Slack: `@opsbot: deploy cog to staging`
* Slack: `@opsbot: deploy cog:imbriaco/staging to staging`
* CLI: `convox logs`
* CLI: `convox scale bot --count 1 --memory 1024`

Finally, you can run an interactive shell in the staging environment. Keep in mind that this shell is in a new container for each run, so won't have direct access to the container(s) where `bot` processes run, but is still very handy to have access to `mix`, `iex`, `make` and so on in an identical container with the same environment settings.

```
$ convox run bot /bin/bash
root@839ed037076d:/app# iex
Erlang/OTP 18 [erts-7.1] [source-2882b0c] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false]

Interactive Elixir (1.1.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

#### Interactive Development with Embedded Command Bundle

Start up Cog with a clean database

    make reset-db run

In another terminal, run the bootstrap script:

    scripts/bootstrap.exs
    mix run scripts/dev_setup.exs

This can also be used when demoing Cog.

To clear out the database from within a running server, run:

    Cog.Support.ModelUtilities.clean_db!

This will also restart the bundle supervision tree, ensuring that you
won't have old bundles running when you try to install new ones.
