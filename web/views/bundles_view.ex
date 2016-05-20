defmodule Cog.V1.BundlesView do
  use Cog.Web, :view

  # alias Cog.V1.RelayGroupView
  # alias Cog.V1.CommandView
  # alias Cog.V1.PermissionView

  def render("bundle.json", %{bundle: bundle, enabled_bundles: enabled_bundles}=_params) do
    case Map.get(enabled_bundles, bundle.name) do
      nil ->
        %{id: bundle.id,
          name: bundle.name,
          enabled: false,
          inserted_at: bundle.inserted_at,
          updated_at: bundle.updated_at,
          relay_groups: []}
          # |> Map.merge(render_includes(params, bundle))
      version ->
        %{id: bundle.id,
          name: bundle.name,
          enabled: true,
          version: to_string(version),
          inserted_at: bundle.inserted_at,
          updated_at: bundle.updated_at}
    end
  end

  def render("index.json", %{bundles: bundles}=assigns) do
    %{bundles: render_many(bundles, __MODULE__,
                           "bundle.json",
                           Map.put(assigns, :as, :bundle))}
  end

  def render("show.json", %{bundle: bundle, warnings: warnings}=assigns)
  when length(warnings) > 0 do
    warnings = Enum.map(warnings, fn({msg, meta}) -> ~s(Warning near #{meta}: #{msg}) end)
    %{warnings: warnings,
      bundle: render_one(bundle, __MODULE__, "bundle.json",
                         Map.merge(assigns,
                                   %{as: :bundle,
                                     include: [:commands, :relay_groups, :namespace]}))}
  end
  def render("show.json", %{bundle: bundle}=assigns) do
    %{bundle: render_one(bundle, __MODULE__,
                         "bundle.json",
                         Map.merge(assigns,
                                   %{as: :bundle,
                                     include: [:commands, :relay_groups, :namespace]}))}
  end

  # defp render_includes(inc_fields, resource) do
  #   Map.get(inc_fields, :include, [])
  #   |> Enum.reduce(%{}, fn(field, reply) ->
  #     case render_include(field, resource) do
  #       nil -> reply
  #       {key, value} -> Map.put(reply, key, value)
  #     end
  #   end)
  # end

  # defp render_include(:commands, bundle) do
  #   value = Map.fetch!(bundle, :commands)
  #   case Ecto.assoc_loaded?(value) do
  #     true ->
  #       {:commands, render_many(value, CommandView, "command.json", as: :command, include: [:rules])}
  #     false ->
  #       nil
  #   end
  # end
  # defp render_include(:relay_groups, bundle) do
  #   value = Map.fetch!(bundle, :relay_groups)
  #   case Ecto.assoc_loaded?(value) do
  #     true ->
  #       {:relay_groups, render_many(value, RelayGroupView, "relay_group.json", as: :relay_group)}
  #     false ->
  #       nil
  #   end
  # end
  # defp render_include(:namespace, bundle) do
  #   namespace = Map.fetch!(bundle, :namespace)
  #   case Ecto.assoc_loaded?(namespace) do
  #     true ->
  #       {:permissions, render_many(namespace.permissions, PermissionView, "permission.json", as: :permission, include: [:namespace])}
  #     false ->
  #       nil
  #   end
  # end
end
