defmodule Cog.Repository.Templates do

  require Ecto.Query
  import Ecto.Query, only: [from: 2]
  alias Cog.Repo

  def refresh_common_templates! do
    templates = templates_from_files(Cog.Template.template_dir(:common))

    # Delete any old common templates that are no longer being used
    # (i.e., their template file was removed)
    template_names = Map.keys(templates)
    Repo.delete_all(from t in common_templates,
                    where: not(t.name in ^template_names))

    Enum.map(templates, fn({name, %{"body" => source}}) ->
      refresh_template(name, source)
    end)
  end

  def create_template!(bundle_version, {name, %{"body" => source}}) do
    # TODO: Unsure if this final newline stripping is necessary any longer
    source = String.replace(source, ~r{\n\z}, "")

    params = %{adapter: Cog.Template.default_provider,
               name: name,
               source: source}

    bundle_version
    |> Ecto.build_assoc(:templates)
    |> Cog.Models.Template.changeset(params)
    |> Repo.insert!
  end

  ########################################################################

  # TODO: Wonder if this should go into Cog.Template instead?
  @doc """
  Given a directory, extract all template sources, returning a map of
  template name => template source.

  Used for the embedded bundle templates as well as common templates.
  """
  def templates_from_files(dir) do
    paths = Path.wildcard("#{dir}/*#{Cog.Template.extension}")

    Enum.reduce(paths, %{}, fn(path, acc) ->
      name = Path.basename(path, Cog.Template.extension)
      source = File.read!(path)
      Map.put(acc, name, %{"body" => source})
    end)
  end

  ########################################################################

  # If a common template named `name` exists, set its body to
  # `source`. Otherwise, insert a new template.
  defp refresh_template(name, source) do
    (find_common_template(name) || %Cog.Models.Template{})
    |> Cog.Models.Template.changeset(%{adapter: Cog.Template.default_provider,
                                       name: name,
                                       source: source})
    |> Repo.insert_or_update!
  end

  # Composable Ecto query fragment that defines our common / fallback
  # templates. This should be used as a starting point for all
  # database queries dealing with these templates to ensure consistency.
  defp common_templates do
    provider = Cog.Template.default_provider
    from t in Cog.Models.Template,
    where: is_nil(t.bundle_version_id),
    where: t.adapter == ^provider
  end

  defp find_common_template(name),
    do: Repo.one(from t in common_templates, where: t.name == ^name)

end
