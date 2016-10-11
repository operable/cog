defmodule Cog.Config.Helpers do

  # List of available chat providers. Only one can be enabled at a time.
  @chat_providers [slack: Cog.Chat.Slack.Provider,
                   hipchat: Cog.Chat.HipChat.Provider]
  # Other providers. These are all enabled.
  @other_providers [http: Cog.Chat.Http.Provider]

  def data_dir do
    System.get_env("COG_DATA_DIR") || Path.expand(Path.join([Path.dirname(__ENV__.file), "..", "data"]))
  end

  def data_dir(subdir) do
    Path.join([data_dir, subdir])
  end

  def ensure_integer(ttl) when is_nil(ttl), do: false
  def ensure_integer(ttl) when is_binary(ttl), do: String.to_integer(ttl)
  def ensure_integer(ttl) when is_integer(ttl), do: ttl

  def ensure_boolean(nil), do: nil
  def ensure_boolean(value) when is_boolean(value), do: value
  def ensure_boolean(value) when is_binary(value) do
    value
    |> String.downcase
    |> string_to_boolean
  end

  # Returns a list containing the enabled chat provider and all other providers.
  # Or nil if no provider is specified.
  def provider_list do
    case Enum.find(@chat_providers, &enabled_provider?/1) do
      nil -> nil
      provider -> List.wrap(provider) ++ @other_providers
    end
  end

  def enabled_chat_provider do
    # I'm using filter here so we can give some feedback to the user if they
    # specify multiple providers.
    case Enum.filter(@chat_providers, &enabled_provider?/1) do
      [] ->
        nil
      [{provider, _module}] ->
        provider
      _ ->
        # Multiple providers were specified.
        raise("Multiple chat providers were specified. You can only enable one provider at a time.")
    end
  end

  defp string_to_boolean("true"), do: true
  defp string_to_boolean(_), do: false

  defp provider_var(provider) when is_atom(provider),
    do: "COG_" <> (Atom.to_string(provider) |> String.upcase) <> "_ENABLED"

  defp enabled_provider?({provider, _module}) do
    provider_var(provider)
    |> System.get_env
    |> is_set?
  end

  defp is_set?(val), do: not(is_nil(val))

end
