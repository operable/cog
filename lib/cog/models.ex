defmodule Cog.Models do
  @moduledoc """
    Convenience module for easily aliasing all the model classes in the
    application at once.

    Use this in whatever modules need to interact with the models.

    Example:

      defmodule MyStuff do
        use Cog.Models

        def stuff() do
          %User{...}
          # instead of %Cog.Models.User{...}
        end
      end
  """
  defmacro __using__(_) do
    quote do
      alias Cog.Models.Bundle
      alias Cog.Models.ChatProvider
      alias Cog.Models.ChatHandle
      alias Cog.Models.User
      alias Cog.Models.Permission
      alias Cog.Models.Permission.Namespace
      alias Cog.Models.UserPermission
      alias Cog.Models.Group
      alias Cog.Models.GroupPermission
      alias Cog.Models.UserGroupMembership
      alias Cog.Models.GroupGroupMembership
      alias Cog.Models.Role
      alias Cog.Models.UserRole
      alias Cog.Models.Command
      alias Cog.Models.CommandOption
      alias Cog.Models.Rule
      alias Cog.Models.RulePermission
      alias Cog.Models.Token
      alias Cog.Models.Template
      alias Cog.Models.UserCommandAlias
      alias Cog.Models.SiteCommandAlias
    end
  end
end
