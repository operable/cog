defmodule Cog.Commands.Unique do
  @moduledoc """
  This command returns unique values given list of inputs

  Examples:
  > @bot operable:unique 49.3 9 2 2 42 49.3
  > @bot operable:unique "apple" "apple" "ball" "car" "car" "zebra"
  """
  use Cog.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, execution: :once

  def handle_message(req, state) do
    entries = get_entries(req)
    |> Enum.uniq
    {:reply, req.reply_to, entries, state}
  end

  defp get_entries(%{cog_env: cog_env, args: args}) when is_nil(cog_env),
    do: args
  defp get_entries(%{cog_env: cog_env, args: args}),
    do: List.flatten([cog_env] ++ args)
end
