@moduledoc """
A schema is a keyword list which represents how to map, transform, and validate
configuration values parsed from the .conf file. The following is an explanation of
each key in the schema definition in order of appearance, and how to use them.

## Import

A list of application names (as atoms), which represent apps to load modules from
which you can then reference in your schema definition. This is how you import your
own custom Validator/Transform modules, or general utility modules for use in
validator/transform functions in the schema. For example, if you have an application
`:foo` which contains a custom Transform module, you would add it to your schema like so:

`[ import: [:foo], ..., transforms: ["myapp.some.setting": MyApp.SomeTransform]]`

## Extends

A list of application names (as atoms), which contain schemas that you want to extend
with this schema. By extending a schema, you effectively re-use definitions in the
extended schema. You may also override definitions from the extended schema by redefining them
in the extending schema. You use `:extends` like so:

`[ extends: [:foo], ... ]`

## Mappings

Mappings define how to interpret settings in the .conf when they are translated to
runtime configuration. They also define how the .conf will be generated, things like
documention, @see references, example values, etc.

See the moduledoc for `Conform.Schema.Mapping` for more details.

## Transforms

Transforms are custom functions which are executed to build the value which will be
stored at the path defined by the key. Transforms have access to the current config
state via the `Conform.Conf` module, and can use that to build complex configuration
from a combination of other config values.

See the moduledoc for `Conform.Schema.Transform` for more details and examples.

## Validators

Validators are simple functions which take two arguments, the value to be validated,
and arguments provided to the validator (used only by custom validators). A validator
checks the value, and returns `:ok` if it is valid, `{:warn, message}` if it is valid,
but should be brought to the users attention, or `{:error, message}` if it is invalid.

See the moduledoc for `Conform.Schema.Validator` for more details and examples.
"""
[
  extends: [],
  import: [],
  mappings: [
    "cog.mode": [
      datatype: [enum: [:dev, :test, :prod]],
      default: :prod,
      hidden: true
    ],
    "cog.telemetry": [
      commented: true,
      datatype: :boolean,
      default: true,
      doc: """
      ========================================================================
      Cog Telemetry - By default, Cog is configured to send an event to the
      Operable telemetry service every time it starts. This event contains a
      unique ID (based on the SHA256 of the UUID for your operable bundle),
      the Cog version number, and the Elixir mix environment (:prod, :dev, etc)
      that Cog is running under.

      If you would like to opt-out of sending this data, you can set the
      COG_TELEMETRY environment variable to "false".
      ========================================================================
      """,
      env_var: "COG_TELEMETRY",
    ],
    "cog.rules.mode": [
      commented: true,
      datatype: [enum: [:enforcing, :unenforcing]],
      default: :enforcing,
      doc: """
      ========================================================================
      Set this to :unenforcing to globally disable all access rules.
      NOTE: This is a global setting.
      ========================================================================
      """,
      env_var: "COG_RULE_ENFORCEMENT_MODE",
      to: "cog.access_rules"
    ],
    "cog.db.adapter": [
      hidden: true,
      datatype: [enum: [Ecto.Adapters.Postgres]],
      default: Ecto.Adapters.Postgres,
      to: "cog.Elixir.Cog.Repo.adapter"
    ],
    "cog.db.name": [
      commented: true,
      datatype: :binary,
      default: "cog",
      env_var: "COG_DB_NAME",
      to: "cog.Elixir.Cog.Repo.database"
    ],
    "cog.db.host": [
      commented: true,
      datatype: :binary,
      default: "localhost",
      env_var: "COG_DB_HOST",
      to: "cog.Elixir.Cog.Repo.hostname"
    ],
    "cog.db.port": [
      commented: true,
      datatype: :integer,
      default: 5432,
      env_var: "COG_DB_PORT",
      to: "cog.Elixir.Cog.Repo.port"
    ],
    "cog.db.username": [
      commented: true,
      datatype: :binary,
      env_var: "COG_DB_USER",
      to: "cog.Elixir.Cog.Repo.username"
    ],
    "cog.db.pool_size": [
      commented: false,
      datatype: :integer,
      default: 10,
      env_var: "COG_DB_POOL_SIZE",
      to: "cog.Elixir.Cog.Repo.pool_size"
    ],
    "cog.db.pool_timeout": [
      commented: false,
      datatype: :integer,
      default: 15000,
      env_var: "COG_DB_POOL_TIMEOUT",
      to: "cog.Elixir.Cog.Repo.pool_timeout"
    ],
    "cog.db.timeout": [
      commented: false,
      datatype: :integer,
      default: 15000,
      env_var: "COG_DB_TIMEOUT",
      to: "cog.Elixir.Cog.Repo.timeout"
    ],
    "cog.db.ssl": [
      commented: false,
      datatype: :boolean,
      default: :false,
      env_var: "COG_DB_SSL",
      to: "cog.Elixir.Cog.Repo.ssl"
    ],
    "cog.mqtt_server.host": [
      commented: true,
      datatype: :binary,
      default: "127.0.0.1",
      doc: """
      Message bus server host name
      """,
      to: "cog.message_bus.host",
      env_var: "COG_MQTT_HOST"
    ],
    "cog.mqtt_server.port": [
      commented: true,
      datatype: :integer,
      default: 1883,
      doc: """
      Message bus server port
      """,
      to: "cog.message_bus.port",
      env_var: "COG_MQTT_PORT"
    ],
    "cog.mqtt_server.cert_file": [
      commented: true,
      datatype: :binary,
      doc: """
      Path to SSL certificate
      """,
      to: "cog.message_bus.ssl_cert",
      env_var: "COG_MQTT_CERT_FILE"
    ],
    "cog.mqtt_server.key_file": [
      commented: true,
      datatype: :binary,
      doc: """
      Path to SSL private key file
      """,
      to: "cog.message_bus.ssl_key",
      env_var: "COG_MQTT_KEY_FILE"
    ],
    "cog.mqtt_client.host": [
      commented: true,
      datatype: :binary,
      doc: "Message bus server host name",
      default: "127.0.0.1",
      env_var: "COG_MQTT_HOST"
    ],
    "cog.mqtt_client.port": [
      commented: true,
      datatype: :integer,
      doc: "Message bus server port",
      default: 1883,
      env_var: "COG_MQTT_PORT"
    ],
    "cog.mqtt_client.ssl": [
      commented: true,
      datatype: [enum: [:enabled, :disabled, :no_verify]],
      doc: "Enable/disable SSL",
      default: :disabled
    ],
    "cog.mqtt_client.ssl_cert": [
      commented: true,
      datatype: :binary,
      doc: "Path to message bus server's SSL certificate"
    ],
    "cog.commands.allow_spoken": [
      commented: true,
      datatype: :boolean,
      default: false,
      doc: """
      Enables/disables spoken commands
      """,
      to: "cog.enable_spoken_commands",
      env_var: "ENABLE_SPOKEN_COMMANDS"
    ],
    "cog.command.prefix": [
      commented: true,
      datatype: :binary,
      default: "!",
      doc: """
      Prefix used to indicate spoken command
      """,
      env_var: "COG_COMMAND_PREFIX"
    ],
    "cog.command.max_alias_depth": [
      commented: true,
      datatype: :integer,
      default: 5,
      doc: "Maximum command alias expansion depth",
      to: "cog.max_alias_expansion"
    ],
    "cog.pipeline.timeout": [
      commented: true,
      datatype: :integer,
      default: 60,
      doc: "Interactive pipeline execution timeout",
      to: "cog.Cog.Command.Pipeline.interactive_timeout",
      env_var: "COG_PIPELINE_TIMEOUT"
    ],
    "cog.trigger.timeout": [
      commented: true,
      datatype: :integer,
      default: 300,
      doc: "Trigger execution timeout",
      env_var: "COG_TRIGGER_TIMEOUT"
    ],
    "cog.trigger.timeout_buffer": [
      commented: true,
      datatype: :integer,
      default: 2,
      doc: """
      Trigger timeouts are defined according to the needs of the
      requestor, which includes network roundtrip time, as well as Cog's
      internal processing. Cog itself can't wait that long to respond, as
      that'll be guaranteed to exceed the HTTP requestor's timeout. As
      such, we'll incorporate a buffer into our internal timeout. Defined
      as seconds
      """,
      env_var: "COG_TRIGGER_TIMEOUT_BUFFER",
      to: "cog.trigger_timeout_buffer"
    ],
    "cog.embedded_bundle_version": [
      commented: true,
      datatype: :binary,
      default: "0.15.0",
      doc: """
      ========================================================================
      Embedded Command Bundle Version (for built-in commands)
      NOTE: Do not change this value unless you know what you're doing.
      ========================================================================
      """
    ],
    "cog.chat.providers": [
      commented: true,
      datatype: [list: :atom],
      doc: "Enabled chat providers",
      default: Cog.Chat.Slack.Provider
    ],
    "cog.chat.slack.api_token": [
      commented: true,
      datatype: :binary,
      doc: "Slack API token",
      env_var: "SLACK_API_TOKEN",
    ],
    "cog.chat.hipchat.api_token": [
      commented: true,
      datatype: :binary,
      doc: "HipChat API token",
      env_var: "HIPCHAT_API_TOKEN"
    ],
    "cog.chat.hipchat.jabber_id": [
      commented: true,
      datatype: :binary,
      doc: "HipChat Jabber ID",
      env_var: "HIPCHAT_JABBER_ID"
    ],
    "cog.chat.hipchat.jabber_password": [
      commented: true,
      datatype: :binary,
      doc: "HipChat Jabber Password",
      env_var: "HIPCHAT_JABBER_PASSWORD"
    ],
    "cog.chat.hipchat.nickname": [
      commented: true,
      datatype: :binary,
      doc: "HipChat nickname",
      env_var: "HIPCHAT_NICKNAME"
    ],
    "cog.chat.hipchat.api_root": [
      commented: true,
      datatype: :binary,
      default: "https://api.hipchat.com/v2",
      env_var: "HIPCHAT_API_ROOT"
    ],
    "cog.chat.hipchat.chat_host": [
      commented: true,
      datatype: :binary,
      default: "chat.hipchat.com",
      env_var: "HIPCHAT_CHAT_HOST"
    ],
    "cog.chat.hipchat.conf_host": [
      commented: true,
      datatype: :binary,
      default: "conf.hipchat.com",
      env_var: "HIPCHAT_CONF_HOST"
    ],
    "cog.caches.command.ttl": [
      commented: true,
      datatype: :integer,
      doc: "Commmand cache TTL (in seconds)",
      default: 60,
      to: "cog.command_cache_ttl"
    ],
    "cog.caches.rule.ttl": [
      commented: true,
      datatype: :integer,
      doc: "Access rule cache TTL (in seconds)",
      default: 60,
      to: "cog.command_rule_cache_ttl"
    ],
    "cog.caches.template.ttl": [
      commented: true,
      datatype: :integer,
      doc: "Template cache TTL (in seconds)",
      default: 60,
      to: "cog.command_template_cache_ttl"
    ],
    "cog.caches.user_perms.ttl": [
      commented: true,
      datatype: :integer,
      doc: "User permission cache TTL (in seconds)",
      default: 60,
      to: "cog.user_perms_ttl"
    ],
    "cog.allow_self_registration": [
      commented: true,
      datatype: :boolean,
      doc: "Automatically create Cog user accounts for unknown users",
      default: false,
      to: "cog.self_registration"
    ],
    "cog.email.from_address": [
      commented: true,
      datatype: :binary,
      doc: "Email address used to send password reset emails, etc",
      default: "cog@localhost",
      env_var: "COG_EMAIL_FROM",
      to: "cog.email_from"
    ],
    "cog.urls.password_reset_base": [
      datatype: :binary,
      default: "",
      env_var: "COG_PASSWORD_RESET_BASE_URL",
      to: "cog.password_reset_base_url"
    ],
    "cog.urls.trigger_base": [
      datatype: :binary,
      default: "",
      env_var: "COG_TRIGGER_URL_BASE",
      to: "cog.trigger_url_base"
    ],
    "cog.urls.service_base": [
      datatype: :binary,
      default: "",
      env_var: "COG_SERVICE_URL_BASE",
      to: "cog.services_url_base"
    ],
    "cog.api_token.lifetime": [
      commented: true,
      datatype: :integer,
      default: 1
    ],
    "cog.api_token.lifetime_units": [
      commented: true,
      datatype: [enum: [:sec, :min, :day, :week]],
      default: :week
    ],
    "cog.api_token.reap_interval": [
      commented: true,
      datatype: :integer,
      default: 1
    ],
    "cog.api_token.reap_interval_units": [
      commented: true,
      datatype: [enum: [:sec, :min, :day, :week]],
      default: :day
    ]
  ],
  transforms: [
    "cog.urls.trigger_base": fn(tbl) -> case Conform.Conf.get(tbl, "cog.urls.trigger_base") do
                                          [] ->
                                            []
                                          [value] ->
                                            String.replace(value, ~r/\/$/, "")
                                        end end,
    "cog.urls.service_base": fn(tbl) -> case Conform.Conf.get(tbl, "cog.urls.service_base") do
                                          [] ->
                                            []
                                          [value] ->
                                            String.replace(value, ~r/\/$/, "")
                                        end end,
  ],
  validators: []
]
