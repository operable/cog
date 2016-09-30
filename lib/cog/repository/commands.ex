defmodule Cog.Repository.Commands do
  import Ecto.Query, only: [from: 2]

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

  def with_status_by_any_name(name) do
    query = from cv in CommandVersion,
            join: c in assoc(cv, :command),
            join: b in assoc(c, :bundle),
            join: bv in assoc(cv, :bundle_version),
            left_join: e in "enabled_bundle_versions",
              on: bv.bundle_id == e.bundle_id and bv.version == e.version,
            order_by: [desc: not(is_nil(e.version)), desc: bv.version],
            distinct: b.id,
            select: %{command_version: cv, enabled: not(is_nil(e.bundle_id))}

    query = case String.split(name, ":", parts: 2) do
      [bundle, command] ->
        from cv in query,
        join: c in assoc(cv, :command),
        join: b in assoc(c, :bundle),
        where: b.name == ^bundle and c.name == ^command
      [command] ->
        from cv in query,
        join: c in assoc(cv, :command),
        where: c.name == ^command
    end

    Enum.map(Repo.all(query), fn
      %{command_version: command_version, enabled: true} ->
        command_version
        |> Map.put(:status, "enabled")
        |> Repo.preload(command: :bundle)
      %{command_version: command_version, enabled: false} ->
        command_version
        |> Map.put(:status, "disabled")
        |> Repo.preload(command: :bundle)
    end)
  end

  def preloads_for_help(command_versions) do
    Repo.preload(command_versions, [:command, :bundle_version, options: :option_type])
  end
end
