defmodule Cog.Test.Commands.Permission.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  alias Cog.Commands.Permission.List

  test "listing permissions works" do
    payload = new_req(args: [])
              |> send_req(List)
              |> unwrap()
              |> Enum.sort_by(fn(p) -> "#{p[:bundle]}:#{p[:name]}" end)

    assert [%{bundle: "operable", name: "manage_commands"},
            %{bundle: "operable", name: "manage_groups"},
            %{bundle: "operable", name: "manage_permissions"},
            %{bundle: "operable", name: "manage_relays"},
            %{bundle: "operable", name: "manage_roles"},
            %{bundle: "operable", name: "manage_triggers"},
            %{bundle: "operable", name: "manage_users"},
            %{bundle: "operable", name: "st-echo"},
            %{bundle: "operable", name: "st-thorn"}] = payload
  end
end
