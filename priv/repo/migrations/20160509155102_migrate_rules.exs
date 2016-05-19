defmodule Cog.Repo.Migrations.MigrateRules do
  use Ecto.Migration

  alias Cog.Repo
  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  require Logger

  # This would have been done in the previous migration, but we need
  # the Piper parsing in here. Since this is "live" code, it gets
  # executed before any of the DSL statements would (since those are
  # accumulated and actually run once the whole file has been read).
  #
  # If it's the only thing in the script, though, we're good
  def change do
    # Hoist rules up, linking them to bundles...
    site_version = site_bundle_version_id

    Repo.all(all_rules)
    |> Enum.map(&parse_tree_to_rule/1)
    |> Enum.group_by(&rule_bundle/1)
    |> Enum.each(fn({bundle_name, rules}) ->
      # For each version of a bundle, get bundle config_file
      versions = versions_for_bundle(bundle_name)
      |> Repo.all
      |> Enum.map(&extract_rules_for_config/1)

      rules
      |> Enum.each(fn(r) ->
        ids = case r[:text] |> versions_with_rules(versions) |> version_ids do
                [] ->
                  [site_version]
                ids ->
                  ids
              end
        Enum.each(ids, fn(bundle_version_id) ->
          execute """
          INSERT INTO rule_bundle_version_v2(rule_id, bundle_version_id)
          VALUES('#{Cog.UUID.bin_to_uuid(r[:id])}', '#{Cog.UUID.bin_to_uuid(bundle_version_id)}')
          """
        end)
      end)
    end)

  end

  ########################################################################

  defp all_rules do
    from r in "rules",
    select: %{id: r.id, parse_tree: r.parse_tree}
  end

  defp parse_tree_to_rule(rule) do
    parsed_rule = Piper.Permissions.Parser.json_to_rule!(rule[:parse_tree])

    rule
    |> Map.put(:rule, parsed_rule)
    |> Map.put(:text, to_string(parsed_rule))
  end

  defp rule_bundle(rule) do
    rule[:rule].command
    |> String.split(":")
    |> List.first
  end

  defp versions_for_bundle(bundle_name) do
    from bv in "bundle_versions_v2",
    join: b in "bundles_v2", on: b.id == bv.bundle_id,
    where: b.name == ^bundle_name,
    select: %{bundle: b.name, bundle_id: b.id, bundle_version_id: bv. id, config_file: bv.config_file}
  end

  defp extract_rules_for_config(%{config_file: config}=rule) do
    rules = config
    |> Map.get("commands", %{})
    |> Enum.flat_map(fn({_cmd, m}) -> Map.get(m, "rules", []) end)

    Map.put(rule, :all_rules, rules)
  end

  defp site_bundle_version_id do
    case "site"
    |> versions_for_bundle
    |> Repo.one do
      nil ->
        nil
      version ->
        Map.fetch!(version, :bundle_version_id)
    end
  end

  defp rule_in_version?(rule_text, %{all_rules: rules}),
    do: Enum.member?(rules, rule_text)

  defp versions_with_rules(rule_text, bundle_versions) do
    Enum.filter(bundle_versions, &rule_in_version?(rule_text, &1))
  end

  defp version_ids(bundle_versions),
    do: Enum.map(bundle_versions, &(&1[:bundle_version_id]))

end
