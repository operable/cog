defmodule Cog.EmailCase do
  @moduledoc """
  Case template used for testing emails.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Bamboo.Test
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, {:shared, self()})

    :ok
  end

end
