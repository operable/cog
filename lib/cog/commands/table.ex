defmodule Cog.Commands.Table do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  alias Cog.Command.Service.MemoryClient
  alias Cog.Formatters.Table

  @moduledoc """
  Converts the given list into a table of columns with headers.

  ## Usage

    table [columns...]

    Columns specify the keys in the json to include in the table;
    these column names are also used as headers. If no columns are
    provided, the columns will be made up of all existing keys.

  ## Examples

    @cog seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table
    > pizza     price
      cheese    $10
      peperoni  $12

    @cog seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table pizza
    > pizza   
      cheese  
      peperoni

    @cog seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table price pizza
    > price  pizza
      $10    cheese
      $12    peperoni
  """

  rule "when command is #{Cog.embedded_bundle}:table allow"

  def handle_message(req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    step  = req.invocation_step
    value = req.cog_env
    args  = req.args

    MemoryClient.accum(root, token, key, value)

    case step do
      step when step in ["first", nil] ->
        {:reply, req.reply_to, nil, state}
      "last" ->
        accumulated_value = MemoryClient.fetch(root, token, key)
        table = tableize(accumulated_value, args)
        MemoryClient.delete(root, token, key)
        {:reply, req.reply_to, "table", %{"table" => table}, state}
    end
  end

  defp tableize(items, []) do
    headers = items
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq

    tableize(items, headers)
  end

  defp tableize(items, headers) do
    rows = Enum.map(items, fn item ->
      Enum.map(headers, &Map.get(item, &1, ""))
    end)

    Table.format([headers|rows])
  end
end
