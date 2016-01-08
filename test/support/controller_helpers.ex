defmodule Cog.Controller.Helpers do

  alias Phoenix.ConnTest
  alias Plug.Conn

  @doc """
  Prepare and execute a Cog API request.

  Arguments:

  * `requestor` - a `%User{}` with an associated token. This token
    will be added to the request via an `Authorization` header. All
    request authentication and authorization will be done in terms of
    this user.

  * `method` - an atom representing one of the HTTP verbs: `:get`,
    `:post`, etc.

  * `path` - the path of the request,
    e.g. "/v1/user/898c50f2-0523-4be3-a9a4-16dbc1677a59"

  * `options` - a keyword list of options that may be used to further
    customize the request. The supported options are:

    `body` - a map representing the JSON payload of the
    request. Defaults to `nil`

    `endpoint` - the Phoenix Endpoint the request will be dispatched
    to. Defaults to `Cog.Endpoint`. (Note: until such time as we
    have multiple endpoints, you should use the default.)

  Returns a `%Plug.Conn{}`.

  Examples:

      # List groups
      api_request(user, :get, "/v1/groups")

      # Retrieve a specific user
      api_request(user, :get, "/v1/user/898c50f2-0523-4be3-a9a4-16dbc1677a59")

      # Create a role
      api_request(user, :post, "/v1/roles",
                  body: %{"role" => %{"name" => "admin"}})

  """
  def api_request(requestor, method, path, options \\ []) do
    # Process all options
    defaults = [body: nil,
                endpoint: Cog.Endpoint]
    options = Keyword.merge(defaults, options)
    body = Keyword.fetch!(options, :body)
    endpoint = Keyword.fetch!(options, :endpoint)

    # Obtain a token from the requestor; if more than one is
    # associated with the requestor, we take the first one.
    requestor = Cog.Repo.preload(requestor, :tokens)
    token = hd(requestor.tokens).value

    # Route the request, with appropriate headers in place
    ConnTest.conn()
    |> Conn.put_req_header("accept", "application/json")
    |> Conn.put_req_header("authorization", "token #{token}")
    |> ConnTest.dispatch(endpoint, method, path, body)
  end

  @doc """
  Utility function to sort a list of structs or maps by the value of a
  specified field. Useful to eliminate ordering issues when comparing
  to API responses that are lists.
  """
  def sort_by(things, field) do
    Enum.sort_by(things, fn(t) -> Map.get(t, field) end)
  end

end
