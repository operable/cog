defmodule Cog.Queries do
  defmacro __using__(_) do
    quote do
      use Cog.Models
      import Ecto.Query, only: [from: 2]
    end
  end
end
