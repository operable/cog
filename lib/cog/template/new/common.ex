defmodule Cog.Template.New.Common do
  @moduledoc """
  Logic for installing and upgrading common templates.
  """

  @extension ".greenbar"

  alias Cog.Repo

  require Logger
  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  # TODO: Might be able to leverage some of this in Bundle.Config#gen_templates
  # TODO: Might be able to leverage some of this in Repository.Bundles#create_template!
  # TODO: Create a Template repository??

  def refresh_all_common_templates do
    template_dir
    |> template_paths
    |> templates
    |> Enum.map(fn({name, %{"body" => body}}) ->
      refresh_template(name, body)
    end)
  end

  # upsert the template
  def refresh_template(name, body) do
    params = %{adapter: Cog.Template.New.default_provider,
               name: name,
               source: body}
    template = find_common_template(name) || %Cog.Models.Template{}
    template
    |> Cog.Models.Template.changeset(params)
    |> Repo.insert_or_update!
  end

  def find_common_template(name) do
    adapter = Cog.Template.New.default_provider
    Repo.one(from t in Cog.Models.Template,
             where: t.name == ^name,
             where: is_nil(t.bundle_version_id),
             where: t.adapter == ^adapter)
  end

  # Return a map of name -> template body
  def templates(paths) do
    Enum.reduce(paths, %{}, fn(path, acc) ->
      name = Path.basename(path, @extension)
      contents = File.read!(path)
      Map.put(acc, name, %{"body" => contents})
    end)
  end

  def template_paths(dir),
    do: Path.wildcard("#{dir}/*#{@extension}")

  def template_dir,
    do: Path.join([:code.priv_dir(:cog), "templates", "common"])

end
