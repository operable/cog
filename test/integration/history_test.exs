defmodule Integration.HistoryTest do
  use Cog.AdapterCase, provider: "test"

  @moduletag integration: :general
  @moduletag :command

  @history_indices ["1","2","3","4","5"]

  setup do
    # Create user
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    # Populate pipeline history
    for n <- 1..5 do
      send_message(user, "@bot: operable:echo #{n}")
    end
    {:ok, %{user: user}}
  end

  test "running history with no range returns expected entries", %{user: user} do
    # Massage results to account for ExUnit's randomized test execution
    response = send_message(user, "@bot: operable:history")
               |> Enum.filter(&(Map.get(&1, :index) in @history_indices))
    assert response == [%{index: "5", text: "operable:echo 5 \\| raw"},
                        %{index: "4", text: "operable:echo 4 \\| raw"},
                        %{index: "3", text: "operable:echo 3 \\| raw"},
                        %{index: "2", text: "operable:echo 2 \\| raw"},
                        %{index: "1", text: "operable:echo 1 \\| raw"}]
  end

  test "running history with range returns expected entries", %{user: user} do
    response = send_message(user, "@bot: operable:history 1-3")
    assert response == [%{index: "3", text: "operable:echo 3 \\| raw"},
                        %{index: "2", text: "operable:echo 2 \\| raw"},
                        %{index: "1", text: "operable:echo 1 \\| raw"}]

  end

  test "running history with inverted range returns expected entries", %{user: user} do
    response = send_message(user, "@bot: operable:history 5-3")
    assert response == [%{index: "5", text: "operable:echo 5 \\| raw"},
                        %{index: "4", text: "operable:echo 4 \\| raw"},
                        %{index: "3", text: "operable:echo 3 \\| raw"}]
  end

  test "running history with range args returns expected entries", %{user: user} do
    response = send_message(user, "@bot: operable:history 1 2")
    assert response == [%{index: "2", text: "operable:echo 2 \\| raw"},
                        %{index: "1", text: "operable:echo 1 \\| raw"}]
  end

  test "running history with inverted range args returns expected entries", %{user: user} do
    response = send_message(user, "@bot: operable:history 2 1")
    assert response == [%{index: "2", text: "operable:echo 2 \\| raw"},
                        %{index: "1", text: "operable:echo 1 \\| raw"}]
  end

  test "running history with range start returns expected entries", %{user: user} do
    response = send_message(user, "@bot: operable:history 2")
    assert Enum.count(response) >= 4
    response = Enum.filter(response, &(Map.get(&1, :index) in @history_indices))
    assert response == [%{index: "5", text: "operable:echo 5 \\| raw"},
                        %{index: "4", text: "operable:echo 4 \\| raw"},
                        %{index: "3", text: "operable:echo 3 \\| raw"},
                        %{index: "2", text: "operable:echo 2 \\| raw"}]
  end

  test "limit option restricts number of returned entries", %{user: user} do
    response = send_message(user, "@bot: operable:history --limit 3")
    assert Enum.count(response) == 3
    response = send_message(user, "@bot: operable:history 1 --limit 4")
    assert Enum.count(response) == 4
    response = send_message(user, "@bot: operable:history 5 --limit 10")
    refute Enum.empty?(response)
  end

end
