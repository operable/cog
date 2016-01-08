# Commands

## Architecture Overview

The chatbot is split up into 3 major components: adapters, the command
processor and commands. Messages from your chat client are pulled in with an
adapter. From there the the message is parsed and authorized by the command
processor. If the user has the correct permissions, the message is sent to the
command to be executed and the responses are sent back to the originating
adapter, which pushes the message back into your chat room.

We use a message bus to move messages throughout the system. When the adapter
receives a new message from the chatroom, it pushes a messages on the bus with
a topic that the command processor is listening to. Commands listen for
messages that have already been authorized, and then push responses back onto
the bus with the reply topic embedded in the message. The follow diagram shows
how messages flow through through the message bus to each component.


                                  +----------------+
                                  | Chat Providers |
                                  +---------^------+
                                          | |
                   +-----------+     +----v-----+
                   | Processor |     | Adapters |
                   +------^----+     +------^---+
                        | |               | |
                +-------v-----------------v----------+
                              Message Bus
                +---------------------------^--------+
                                          | |
                                     +----v-----+
                                     | Commands |
                                     +----------+


## Building Our First Command


Commands really only do two things: subscribe to incoming messages and publish
responses. Let's build a simple echo command in Elixir.

First we'll need to subscribe to the message bus. The
[emqtt client library](https://github.com/emqtt/emqttc) can help us pull
messages off of the bus with an implementation of a
[GenServer](http://elixir-lang.org/docs/stable/elixir/GenServer.html). Let's
start by creating a GenServer and connecting to the message bus.

```elixir
defmodule Cog.Commands.Echo do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    opts = [host: {127, 0, 0, 1}, port: 1883, logger: {:lager, :error}]
    {:ok, conn} = :emqttc.start_link(opts)

    :emqttc.subscribe(conn, "/bot/commands/echo", :qos1)

    {:ok, conn}
  end
end
```

You'll notice I subscribed to "/bot/commands/echo". This is the topic the
command processor will publish our echo commands to once it has parsed and
authorized the command. Now that we're subscribed and waiting for messages, we
need to implement a `handle_info/2` callback function, so we can respond to an
incoming message. In the body of the message we'll decode the JSON that the
processor sent us, gather up some new data as a response, encode that and push
it back on the message bus with the topic that was sent to us.

```elixir
  def handle_info({:publish, "/bot/commands/echo", payload}, conn) do
    payload = Poison.decode!(payload)

    %{"text" => text, "reply" => reply} = payload
    text = String.replace(text, ~r/^echo /, "")

    message = payload
    |> Map.take(["room"])
    |> Map.merge(%{"template" => "raw", "assigns" => %{"raw" => text}})
    |> Poison.encode!

    :emqttc.publish(conn, reply, message)

    {:noreply, conn}
  end
  def handle_info(_, conn) do
    {:noreply, conn}
  end
```

There's a lot going on here so let me break down the `handle_info/2`
function. Look at the arguments we're pattern matching. This allows us to
specifically handle messages that have been published to the
"/bot/commands/echo" topic (even if we've subscribed to multiple topics). The
3rd element in the tuple, is the `payload`; a string of JSON sent to us from
the processor. It includes things like the arguments of the parsed command, the
room the command was sent from and the topic that we should send our replies to.

Ok so now that we've decoded the payload, we need to form our response.
Responses will also be encoded as JSON and will end up looking like this:

```json
{
  "room": {
    "id": "CXXXXXXXX"    # Room to respond in
  },
  "template": "raw",     # Name of the template to render
  "assigns": {           # Data used to render the template
    "raw": "Hello world"
  }
}
```

In the echo example we remove the first part of the command call, "echo ", and
then include the rest as part of the "assigns" data. Once we've formed the
response we can just encode it as JSON and tell emqtt to publish it back to the
"reply" topic that was given to us as part of the payload.

So you created a command, now let's run it. You'll need to do three things to
get the command working.

1. Tell the bot how to run the process

   Open up your bot's repo and find `lib/cog/command_sup.ex`. You can
   add the command you build here as a worker like this:

   ```elixir
   def init(_) do
     children = [worker(Cog.Commands.Echo, [])]
     supervise(children, strategy: :one_for_one)
   end
   ```

   Once you restart that supervisor should take care of running your command.

2. Insert the command arguments into the database

   You'll need to tell the processor the name of the command and how to
   parse its arugments. For a command named "add" that takes two arguments
   you would created the following records:

   ```elixir
   command = Repo.insert!(%Command{name: "add", version: "0.0.1"})
   Repo.insert!(Ecto.Model.build(command, :args, name: "left", rank: 0))
   Repo.insert!(Ecto.Model.build(command, :args, name: "right", rank: 1))
   ```

3. Create permissions and rules

   Now we just need to tell the processor how to whitelist a command for a
   user. You'll need to create a permission for the command, a rule to evaluate
   the permission and then grant that permission to a user.

   ```elixir
   # Create permission
   namespace = Repo.insert!(%Namespace{name: "add"})
   permission = Repo.insert!(Ecto.Model.build(namespace, :permissions, name: "read"))

   # Create rule for permission
   rule = "when command is add must have add:read"
   {:ok, parse_tree} = Permissions.Parser.parse(rule)
   Repo.insert!(Ecto.Model.build(command, :rules, parse_tree: parse_tree))

   # Grant permission to user
   Repo.insert!(%UserPermission{user_id: user.id, permission: permission.id})
   ```

Now you should be able to run "@chatbot: add 1 2" and your command will be
parsed, authorized and executed.

## Command Helpers

When creating a command we have a few functions written to help with common
tasks like subscribing to the message bus or creating permissions.

### Command GenServer

If you want to avoid writing your own GenServer you can `use Command` and
provide the name and doc strings. Then all you have to do is define a
`run` function that takes the decoded payload and GenServer state as it's
two arguments. You can use the `send_reply/3` and `send_raw_reply/3` to
respond and then return `{:ok, state}` to indicate a successful command
execution. The echo command from above would look like this:

```elixir
defmodule Cog.Commands.Echo do
  use Cog.Command,
    name: :echo,
    doc: ["echo <message ...>", "Prints the message"]

  def run(%{"text" => text} = payload, %{mq_conn: mq_conn} = state) do
    text = String.replace(text, ~r/^echo /, "")
    send_raw_reply(text, payload, mq_conn)

    {:ok, state}
  end
end
```

### Creating Rules and Granting Permissions

Instead of creating database records manually we have a few helpers:

Creating a rule for a command:

```elixir
Demo.add_rule_for("echo", "when command is echo must have echo:read")
```

Granting a permission to a user:

```elixir
Demo.grant("echo", permission: "read", to: "kaleisdelicious1988"
```
