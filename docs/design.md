* Chat-provider specifics are hidden by abstract interfaces
    1. Sending/receiving messages
    2. Joining/leaving/enumerating public rooms and private chats
    3. Resolving canonical chat IDs to human-friendly names (rooms,
       users, etc)
* Loosely coupled message-driven core
    1. Pub/sub and send/receive operations should be hidden by
    abstract interface(s). This will allow swapping messaging
    transport to achieve different goals.
    2. Components' primary API should be messaging based and, ideally,
       self describing or at least described via some sort of computer
       readable contract.
* Fine grained RBAC controls
* RBAC role assignments and user definitions should be stored in a
  single data store such as Postgres. Ideally the data store will be
  performant, HA capable, and secure.
* User credentials of any kind will be encrypted at rest.
* Extensibility will be a strongly supported first-class concept.
    1. New server commands, similar to hubot scripts, will be packaged
       in a format which supports verification and validation of
       package contents.
    2. Unlike hubot scripts, new server commands require an
       installation process. Installing new commands will controlled
       via RBAC roles.
    3. We'll support implementing new commands in several different
       languages besides Elixir/Erlang.
* Extensive logging and auditing
* Friendly web admin interface
* Targets: Slack, HipChat, irc (maybe)
* Proposed tech stack:
    - Language: Elixir/Erlang
    - Messagiing: Modified Phoenix PubSub for single node installs;MQTT or
    RabbitMQ for multi-node installs
    - Datastore: Postgres
    - RBAC: TBD (probably in-house)
    - Chat libraries [slack: BlakeWilliams/Elixir-Slack, XMPP: bokner/gen_client
    (?), irc: TBD]
    - Web UI: Phoenix
