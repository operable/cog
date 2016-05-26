defmodule Cog.Repository.Commands do
  use Cog.Queries
  alias Cog.Models.CommandVersion
  alias Cog.Repo
  alias Cog.Repository.Bundles

  def enabled do
    Bundles.enabled
    |> Repo.preload(commands: [command: :bundle])
    |> Enum.flat_map(&(&1.commands))
  end

  def highest_disabled_versions do
    Bundles.highest_disabled_versions
    |> Repo.preload(commands: [command: :bundle])
    |> Enum.flat_map(&(&1.commands))
  end

  def enabled_by_any_name(name) do
    bundle_version_ids = Bundles.enabled
    |> Enum.map(&(&1.id))

    query = case String.split(name, ":", parts: 2) do
      [bundle, command] ->
        from cv in CommandVersion,
        join: c in assoc(cv, :command),
        join: b in assoc(c, :bundle),
        where: cv.bundle_version_id in ^bundle_version_ids and
          b.name == ^bundle and
          c.name == ^command,
        preload: [command: :bundle]
      [command] ->
        from cv in CommandVersion,
        join: c in assoc(cv, :command),
        where: cv.bundle_version_id in ^bundle_version_ids and
          c.name == ^command,
        preload: [command: :bundle]
    end

    Repo.all(query)
  end
end
