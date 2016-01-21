defmodule Cog.Router do
  use Cog.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug Cog.Plug.Event
    plug :accepts, ["json"]
  end

  scope "/", Cog do
    pipe_through :api

    resources "/v1/users", V1.UserController

    resources "/v1/roles", V1.RoleController

    resources "/v1/groups", V1.GroupController
    get "/v1/groups/:id/memberships", V1.GroupMembershipController, :index
    post "/v1/groups/:id/membership", V1.GroupMembershipController, :manage_membership

    resources "/v1/permissions", V1.PermissionController, except: [:update]

    post "/v1/token", V1.TokenController, :create

    post "/v1/users/:id/permissions", V1.PermissionGrantController, :manage_user_permissions
    post "/v1/roles/:id/permissions", V1.PermissionGrantController, :manage_role_permissions
    post "/v1/groups/:id/permissions", V1.PermissionGrantController, :manage_group_permissions

    post "/v1/users/:id/roles", V1.RoleGrantController, :manage_user_roles
    post "/v1/groups/:id/roles", V1.RoleGrantController, :manage_group_roles

    resources "/v1/rules", V1.RuleController, except: [:index, :update]

    resources "/v1/bootstrap", V1.BootstrapController, only: [:index, :create]
    resources "/v1/bundles", V1.BundlesController, only: [:index, :show, :delete]
  end

  scope "/", Cog do
    pipe_through :browser

    get "/websockets", WebSocketController, :index
  end
end
