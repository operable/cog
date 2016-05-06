defmodule Integration.Commands.TableTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic table", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table))
    assert_payload(response, %{table: """
    pizza     price
    cheese    $10
    peperoni  $12
    """ |> String.rstrip})
  end

  test "table with column", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table pizza))
    assert_payload(response, %{table: """
    pizza
    cheese
    peperoni
    """ |> String.rstrip})
  end

  test "table with ordered columns", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"pizza": "cheese", "price": "$10"}, {"pizza": "peperoni", "price": "$12"}]' | table price pizza))
    assert_payload(response, %{table: """
    price  pizza
    $10    cheese
    $12    peperoni
    """ |> String.rstrip})
  end
end
