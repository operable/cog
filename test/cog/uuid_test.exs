defmodule Cog.UUIDTest do
  use Cog.ModelCase
  alias Ecto.Adapters.SQL
  alias Cog.Repo

  doctest Cog.UUID

  test "remove Cog.UUID.uuid_to_bin/1 and Cog.UUID.bin_to_uuid/1 if this test fails" do
    # If this test ever fails, then it means that we can pass "uuid
    # strings" as UUID parameters to Postgres queries without having
    # to first turn them into "uuid binaries" via
    # `Cog.UUID.uuid_to_bin/1`. At that point,
    # `Cog.UUID.uuid_to_bin/1` should be removed from the codebase.
    #
    # Otherwise, we expect to see an error like the following
    # (displayed here with formatting):
    #
    # ** (FunctionClauseError) no function clause matching in Postgrex.Extensions.Binary.encode/4
    # stacktrace:
    # (postgrex) lib/postgrex/extensions/binary.ex:59:
    # Postgrex.Extensions.Binary.encode(%Postgrex.TypeInfo{array_elem: 0, base_type: 0, comp_elems: [],
    #                                                      input: "uuid_in", oid: 2950, output: "uuid_out",
    #                                                      receive: "uuid_recv", send: "uuid_send", type: "uuid"},
    #                                   "2a2edb23-d8d6-4f4a-b32c-4b230c138e95",
    #                                   270387,
    #                                   {9, 4, 4})
    catch_error(SQL.query!(Repo, "SELECT $1::uuid",
          ["2a2edb23-d8d6-4f4a-b32c-4b230c138e95"]))
  end

end
