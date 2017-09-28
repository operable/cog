defmodule Cog.Config.Helpers do
  require Logger

  # List of available chat providers. Only one can be enabled at a time.
  @chat_providers [slack: Cog.Chat.Slack.Provider,
                   hipchat: Cog.Chat.HipChat.Provider]
  # Other providers. These are all enabled.
  @other_providers [http: Cog.Chat.Http.Provider]

  def data_dir do
    System.get_env("COG_DATA_DIR") || Path.expand(Path.join([Path.dirname(__ENV__.file), "..", "data"]))
  end
  def data_dir(subdir), do: Path.join([data_dir(), subdir])

  def ensure_integer(number) when is_nil(number), do: false
  def ensure_integer(number) when is_binary(number), do: String.to_integer(number)
  def ensure_integer(number) when is_integer(number), do: number

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

  ########################################################################
  # Proxy URL Generation
  #
  # If Cog is run behind a proxy, any URLs that are generated should
  # be relative to that proxy.
  #
  # We allow the user to specify what this URL should look like by
  # supplying a URL containing a scheme, host, port, and path; all
  # generated URLs will be based on that given URL.
  #
  # Previously, we allowed this URL to be defined by individual
  # variables for host and port (but neither scheme nor path - an
  # oversight). For now, the individual variables will be honored if
  # they are present, while logging a deprecation warning. If the new
  # "all in one" URL variable is present, however, it takes
  # precedence.
  #
  # Note that this *must* take place at compile time if we wish to set
  # `path` as part of the URL; all other parameter may be altered at
  # runtime.
  def gen_public_url_config(endpoint)
  when endpoint in [Cog.Endpoint, Cog.TriggerEndpoint, Cog. ServiceEndpoint] do
    url = case System.get_env(url_base_variable(endpoint)) do
            nil ->
              nil
            value ->
              URI.parse(value)
          end

    Enum.reduce([:scheme, :host, :port, :path], [], fn(field, kw) ->
      case get_value(url, field, endpoint) do
        nil ->
          kw
        value ->
          Keyword.put(kw, field, value)
      end
    end)
  end

  defp get_value(%URI{}=uri, field, _endpoint),
    do: Map.get(uri, field)
  defp get_value(_uri, field, endpoint) when field in [:host, :port],
    do: retrieve_deprecated_env_var(endpoint, field)
  defp get_value(_uri, _field, _endpoint),
    do: nil

  defp retrieve_deprecated_env_var(endpoint, field) do
    env_var = url_component_variable(endpoint, field)
    if value = System.get_env(env_var) do
      Logger.warn("The environment variable '#{env_var}' is deprecated and will cease to be honored in an upcoming release. Please transition to using '#{url_base_variable(endpoint)}' as soon as you can.")
      value
    end
  end

  # The following two functions are written this way for findability.
  # These *_HOST and *_PORT variables are now deprecated
  defp url_component_variable(Cog.Endpoint, :host),        do: "COG_API_URL_HOST"
  defp url_component_variable(Cog.Endpoint, :port),        do: "COG_API_URL_PORT"
  defp url_component_variable(Cog.ServiceEndpoint, :host), do: "COG_SERVICE_URL_HOST"
  defp url_component_variable(Cog.ServiceEndpoint, :port), do: "COG_SERVICE_URL_PORT"
  defp url_component_variable(Cog.TriggerEndpoint, :host), do: "COG_TRIGGER_URL_HOST"
  defp url_component_variable(Cog.TriggerEndpoint, :port), do: "COG_TRIGGER_URL_PORT"

  defp url_base_variable(Cog.Endpoint),        do: "COG_API_URL_BASE"
  defp url_base_variable(Cog.ServiceEndpoint), do: "COG_SERVICE_URL_BASE"
  defp url_base_variable(Cog.TriggerEndpoint), do: "COG_TRIGGER_URL_BASE"

  # End Proxy URL generation helpers
  ########################################################################

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
