defmodule Cog.Template.New.Resolver do
  @moduledoc """
  Find template source... a bit of an anemic module, admittedly, but
  serves to keep new and old template functionality separated.
  """

  alias Cog.Queries
  alias Cog.Repo

  # This is for common templates (raw, error, etc.)
  def fetch_source(template_name),
    do: fetch_source(Cog.Template.New.default_provider, nil, template_name)

  def fetch_source(_bundle_version_id, nil),
    do: fetch_source(Cog.Template.New.default_provider, nil, "raw") # just do raw for now... need to revisit text and json later
  def fetch_source(bundle_version_id, template_name),
    do: fetch_source(Cog.Template.New.default_provider, bundle_version_id, template_name)

  defp fetch_source(provider, bundle_version_id, template) do
    source = Queries.Template.template_source(provider, bundle_version_id, template)
    |> Repo.one

    case source do
      nil ->
        # TODO: NEED TO FALLBACK HERE
        {:error, :template_not_found}
      source ->
        {:ok, source}
    end
  end

end
