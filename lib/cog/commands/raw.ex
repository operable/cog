defmodule Cog.Command.Raw do
  use Cog.GenCommand.Base, bundle: Cog.embedded_bundle,
                               enforcing: false

  alias Cog.Command.Request


  @moduledoc """
  Show the raw output of a command, exclusive of any templating.

  Useful for seeing the difference between `multiple` and `once`
  execution modes, as well as seeing which fields are available for
  use in `bound` and `all` calling conventions.

  Also useful as a debugging tool for command authors.

  Example:

      @bot #{Cog.embedded_bundle}:echo foo | #{Cog.embedded_bundle}:raw
      > {
          "body": [
            "foo"
          ]
        }

  """
  def handle_message(%Request{cog_env: nil}=req, state),
    do: {:reply, req.reply_to, "nil", state}
  def handle_message(req, state),
    do: {:reply, req.reply_to, "json", req.cog_env, state}

end
