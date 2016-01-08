defmodule Cog.Adapters.SSH do
  use Cog.Queries
  alias Cog.Repo

  import Supervisor.Spec
  @behaviour Cog.Adapter

  def describe_tree() do
    [supervisor(Cog.Adapters.SSH.Sup, [])]
  end

  def lookup_room([id: id]), do:  {:ok, id}
  def lookup_room([name: name]), do: {:ok, name}

  def lookup_user([id: id]), do: lookup_user(id)
  def lookup_user([name: name]), do: lookup_user(name)
  def lookup_user(username) do
    case Repo.get_by(User, username: username) do
      nil -> {:error, :unknown_user}
      user -> {:ok, user}
    end
  end

  def message(room, message) do
    Cog.Adapters.SSH.Server.brodcast_message(room[:name], message)
  end

  def authenticate(user, password) do
    case Repo.one(Cog.Queries.User.for_username_password(user, password)) do
      nil -> false
      _   -> true
    end
  end

end
