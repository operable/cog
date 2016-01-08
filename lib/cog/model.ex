defmodule Cog.Model do
  @moduledoc """
    Base module for all Ecto models in Cog.

    Example:

      defmodule MyModel do
        use Cog.Model
        # awesome stuff...
      end
  """
  defmacro __using__(_) do
    quote do
      alias Cog.Repo
      use Ecto.Model
      use Cog.Models.EctoJson
      import Ecto.Changeset

      # We have made a decision to use UUIDs as primary keys to
      # prevent data leakage via our APIs (e.g., if we use
      # autoincrementing integers, that can indicate the size of our
      # user base.)
      #
      # This allows us to codify this decision in one place and forget
      # it. Thanks, Ecto.Schema documentation!
      @primary_key {:id, Ecto.UUID, autogenerate: true}
      @foreign_key_type Ecto.UUID
    end
  end
end
