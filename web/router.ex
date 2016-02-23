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
    get "/v1/users/:user_id/permissions", V1.PermissionController, :index
    get "/v1/groups/:group_id/permissions", V1.PermissionController, :index
    get "/v1/roles/:role_id/permissions", V1.PermissionController, :index

    post "/v1/token", V1.TokenController, :create

    post "/v1/users/:id/permissions", V1.PermissionGrantController, :manage_user_permissions
    post "/v1/groups/:id/permissions", V1.PermissionGrantController, :manage_group_permissions
    post "/v1/roles/:id/permissions", V1.PermissionGrantController, :manage_role_permissions

    post "/v1/users/:id/roles", V1.RoleGrantController, :manage_user_roles
    post "/v1/groups/:id/roles", V1.RoleGrantController, :manage_group_roles

    get "/v1/rules", V1.RuleController, :show
    resources "/v1/rules", V1.RuleController, only: [:create, :delete]

    resources "/v1/bootstrap", V1.BootstrapController, only: [:index, :create]
    resources "/v1/bundles", V1.BundlesController, only: [:index, :show, :delete]

    get "/v1/bundles/:id/status", V1.BundleStatusController, :show
    post "/v1/bundles/:id/status", V1.BundleStatusController, :manage_status

    resources "/v1/chat_handles", V1.ChatHandleController, only: [:index, :update, :delete]
    get "/v1/users/:id/chat_handles", V1.ChatHandleController, :index
    post "/v1/users/:id/chat_handles", V1.ChatHandleController, :create

  end

  scope "/", Cog do
    pipe_through :browser
  end
end
