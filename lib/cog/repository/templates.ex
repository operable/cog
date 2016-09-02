defmodule Cog.Repository.Templates do

  require Ecto.Query
  import Ecto.Query, only: [from: 2]
  alias Cog.Repo

  def refresh_common_templates! do
    templates = templates_from_files(Cog.Template.New.template_dir(:common))

    # Delete any old common templates that are no longer being used
    # (i.e., their template file was removed)
    template_names = Map.keys(templates)
    Repo.delete_all(from t in common_templates,
                    where: not(t.name in ^template_names))

    Enum.map(templates, fn({name, %{"body" => source}}) ->
      refresh_template(name, source)
    end)
  end

  def create_template!(bundle_version, {name, template}) do
    template
    |> handle_old_and_new_templates
    |> Enum.each(fn({provider, source}) ->

      # TODO: Unsure if this final newline stripping is necessary any longer
      source = String.replace(source, ~r{\n\z}, "")
      params = %{
        adapter: provider,
        name: name,
        source: source
      }

      bundle_version
      |> Ecto.build_assoc(:templates)
      |> Cog.Models.Template.changeset(params)
      |> Repo.insert!
    end)
  end

  ########################################################################

  # TODO: Wonder if this should go into Cog.Template.New instead?
  @doc """
  Given a directory, extract all template sources, returning a map of
  template name => template source.

  Used for the embedded bundle templates as well as common templates.
  """
  def templates_from_files(dir) do
    paths = Path.wildcard("#{dir}/*#{Cog.Template.New.extension}")

    Enum.reduce(paths, %{}, fn(path, acc) ->
      name = Path.basename(path, Cog.Template.New.extension)
      source = File.read!(path)
      Map.put(acc, name, %{"body" => source})
    end)
  end

  ########################################################################

  # While we still support adapter-specific templates, we need to be
  # able to properly ingest those old templates, as well as the new,
  # provider-independent templates.
  #
  # The new ones just have a "body" key; for our current purposes,
  # we'll treat these templates as applying to a default provider. This
  # will fit into our existing database and processing structure. Once
  # the old templates are phased out completely, we can just remove
  # any kind of provider labels.
  #
  # On the other hand, if we get a map without a "body" key, then
  # we're dealing with the old templates. The keys are the name of the
  # provider (e.g., "slack", "hipchat"), and the value is the body.
  defp handle_old_and_new_templates(%{"body" => source}),
    do: [{Cog.Template.New.default_provider, source}]
  defp handle_old_and_new_templates(old_provider_specific_templates),
    do: Map.to_list(old_provider_specific_templates)

  # If a common template named `name` exists, set its body to
  # `source`. Otherwise, insert a new template.
  defp refresh_template(name, source) do
    (find_common_template(name) || %Cog.Models.Template{})
    |> Cog.Models.Template.changeset(%{adapter: Cog.Template.New.default_provider,
                                       name: name,
                                       source: source})
    |> Repo.insert_or_update!
  end

  # Composable Ecto query fragment that defines our common / fallback
  # templates. This should be used as a starting point for all
  # database queries dealing with these templates to ensure consistency.
  defp common_templates do
    adapter = Cog.Template.New.default_provider
    from t in Cog.Models.Template,
    where: is_nil(t.bundle_version_id),
    where: t.adapter == ^adapter
  end

  defp find_common_template(name),
    do: Repo.one(from t in common_templates, where: t.name == ^name)

end
