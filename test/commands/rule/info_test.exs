defmodule Cog.Test.Commands.Rule.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Rule.Info

  alias Cog.Models.Rule
  alias Cog.Repository.Rules

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  test "retrieving a rule by ID works" do
    %Rule{id: id} = Rules.ingest("when command is operable:rule-info allow")
                    |> unwrap()

    payload = new_req(args: [id])
              |> send_req()
              |> unwrap()

    assert %{id: id,
             command: "operable:rule-info",
             rule: "when command is operable:rule-info allow"} == payload
  end

  test "retrieving a non-existent rule fails" do
    error = new_req(args: [@bad_uuid])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'rule' with the id '#{@bad_uuid}'")
  end

  test "retrieving a rule requires an ID" do
    error = new_req(args: [])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "the ID given for retrieving a rule must be a string and a UUID" do
    error = new_req(args: ["not_a_uuid"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Invalid UUID \"not_a_uuid\"")

    error = new_req(args: [123])
            |> send_req()
            |> unwrap_error()
    assert(error == "Argument must be a string")
  end

  test "only one rule can be retrieved at a time" do
    %Rule{id: rule_1_id} = Rules.ingest("when command is operable:rule-info allow") |> unwrap()
    %Rule{id: rule_2_id} = Rules.ingest("when command is operable:bundle-list allow") |> unwrap()

    error = new_req(args: [rule_1_id, rule_2_id])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end
end
