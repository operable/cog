defmodule Cog.Models.EctoJson do
  @moduledoc """
  Tools to facilitate the automatic and customizable generation of
  JSON from annotated Ecto models.
  """

  @render_defaults [policy: :detail,
                    envelope: nil]

  defmacro __using__(_) do
    quote do
      # Strictly speaking, these `register_attribute` calls aren't
      # necessary, but serve as nice documentation for which
      # attributes this module works with.
      #
      # This __MODULE__ is the one we're being `use`d in
      Module.register_attribute(__MODULE__, :summary_fields, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :detail_fields, accumulate: false, persist: false)

      # This __MODULE__ is the one this code you're currently reading
      # is in (note the `unquote`)
      import unquote(__MODULE__), only: [summary_fields: 1,
                                         detail_fields: 1]

      @before_compile unquote(__MODULE__)

      summary_fields []
      detail_fields []
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __json_fields__(:summary),
        do: @summary_fields
      def __json_fields__(:detail),
        do: @detail_fields
      def __json_fields__(unrecognized),
        do: raise "Unrecognized JSON rendering policy '#{unrecognized}' for #{__MODULE__}"
    end
  end

  defmacro summary_fields(fields) do
    quote do
      @summary_fields unquote(fields)
    end
  end

  defmacro detail_fields(fields) do
    quote do
      @detail_fields unquote(fields)
    end
  end

  def render(model, opts \\ []) do
    opts = Keyword.merge(@render_defaults, opts)

    policy = Keyword.fetch!(opts, :policy)
    data = do_render(model, policy)
    case Keyword.fetch!(opts, :envelope) do
      nil ->
        data
      envelope ->
        Map.put(%{}, envelope, data)
    end
  end

  # NOTE: render policy cascades to all children. If a parent is
  # rendering as :summary, then so will all children.
  defp do_render(%Ecto.Association.NotLoaded{__field__: field, __owner__: owner}, render_policy) do
    raise "#{__MODULE__}: Tried to render #{owner}.#{field} using render policy '#{render_policy}', but the association is not loaded!"
  end
  defp do_render(%{__struct__: Ecto.DateTime}=ts, _render_policy) do
    ts
  end
  defp do_render(%{__struct__: type}=struct, render_policy) do
    fields = type.__json_fields__(render_policy)

    # TODO: verify that specified fields actually exist in ecto schema?
    Enum.reduce(fields, %{},
      fn(field, acc) ->
        Map.put(acc, field, do_render(Map.get(struct, field), render_policy))
      end)
  end
  defp do_render(list, render_policy) when is_list(list) do
    Enum.map(list, &do_render(&1, render_policy))
  end
  defp do_render(non_struct, _render_policy) do
    non_struct
  end


end
