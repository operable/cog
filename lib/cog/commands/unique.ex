defmodule Cog.Commands.Unique do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, calling_convention: :all, execution: :once

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
