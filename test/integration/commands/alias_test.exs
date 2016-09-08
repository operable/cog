defmodule Integration.Commands.AliasTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Repo

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "creating a new alias", %{user: user} do
    response = send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    assert response, [%{name: "my-new-alias",
                        pipeline: "echo My New Alias",
                        visibility: "user"}]

    created_alias = Repo.get_by(UserCommandAlias, name: "my-new-alias", user_id: user.id)

    assert %{
      name: "my-new-alias",
      pipeline: "echo My New Alias",
      visibility: "user"
    } = created_alias
  end

  test "creating a new alias with an existing name", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    assert_error_message_contains(response, "Whoops! An error occurred. name: The alias name is already in use.")
  end

  test "removing an alias", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias delete my-new-alias")

    assert response == [%{name: "my-new-alias",
                          pipeline: "echo My New Alias",
                          visibility: "user"}]

    deleted_alias = Repo.get_by(UserCommandAlias, name: "my-new-alias", user_id: user.id)

    refute deleted_alias
  end

  test "removing an alias that does not exist", %{user: user} do
    response = send_message(user, "@bot: operable:alias delete my-new-alias")

    assert_error_message_contains(response, "Whoops! An error occurred. I can't find 'my-new-alias'. Please try again")
  end

  test "moving an alias to site using full visibility syntax", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move user:my-new-alias site")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "user"},
                          destination: %{
                            name: "my-new-alias",
                            pipeline: "echo My New Alias",
                            visibility: "site"}}]

    command_alias = Repo.get_by(SiteCommandAlias, name: "my-new-alias")

    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to site using full visibility syntax and rename", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move user:my-new-alias site:my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "user"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "site"
                          }}]

    command_alias = Repo.get_by(SiteCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to site with short syntax", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move my-new-alias site")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "user"},
                          destination: %{
                            name: "my-new-alias",
                            pipeline: "echo My New Alias",
                            visibility: "site"}}]

    command_alias = Repo.get_by(SiteCommandAlias, name: "my-new-alias")

    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to site with short syntax and rename", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move my-new-alias site:my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "user"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "site"}}]

    command_alias = Repo.get_by(SiteCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to user with full visibility syntax", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias move site:my-new-alias user")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "site"},
                          destination: %{
                            name: "my-new-alias",
                            pipeline: "echo My New Alias",
                            visibility: "user"}}]

    command_alias = Repo.get_by(UserCommandAlias, name: "my-new-alias")

    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to user with full visibility syntax and rename", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias move site:my-new-alias user:my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "site"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "user"}}]

    command_alias = Repo.get_by(UserCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to user with short syntax", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias move my-new-alias user")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "site"},
                          destination: %{
                            name: "my-new-alias",
                            pipeline: "echo My New Alias",
                            visibility: "user"}}]

    command_alias = Repo.get_by(UserCommandAlias, name: "my-new-alias")

    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to user with short syntax and rename", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias move my-new-alias user:my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "site"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "user"}}]

    command_alias = Repo.get_by(UserCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "renaming an alias in the user visibility", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move my-new-alias my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "user"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "user"}}]

    command_alias = Repo.get_by(UserCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "renaming an alias in the site visibility", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias move my-new-alias my-renamed-alias")

    assert response == [%{source: %{
                             name: "my-new-alias",
                             pipeline: "echo My New Alias",
                             visibility: "site"},
                          destination: %{
                            name: "my-renamed-alias",
                            pipeline: "echo My New Alias",
                            visibility: "site"}}]

    command_alias = Repo.get_by(SiteCommandAlias, name: "my-renamed-alias")

    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to site when an alias with that name already exists in site", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move user:my-new-alias site")

    assert_error_message_contains(response, "Whoops! An error occurred. name: The alias name is already in use.")
  end

  test "moving an alias to user when an alias with that name already exists in user", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias move site:my-new-alias user")

    assert_error_message_contains(response, "Whoops! An error occurred. name: The alias name is already in use.")
  end

  test "list all aliases", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create my-new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create my-new-alias2 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create my-new-alias3 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias list")

    assert response == [%{visibility: "site",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias"},
                        %{visibility: "user",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias1"},
                        %{visibility: "user",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias2"},
                        %{visibility: "user",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias3"}]
  end

  test "list all aliases matching a pattern", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create my-new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias create new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:alias list \"my-*\"")

    assert response == [%{visibility: "site",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias"},
                        %{visibility: "user",
                          pipeline: "echo My New Alias",
                          name: "my-new-alias1"}]
  end

  test "listing is the default", %{user: user} do
    send_message(user, "@bot: operable:alias create new-alias \"echo My New Alias\"")
    response = send_message(user, "@bot: operable:alias")
    assert response == [%{visibility: "user",
                          pipeline: "echo My New Alias",
                          name: "new-alias"}]
  end

  test "list all aliases with no matching aliases", %{user: user} do
    response = send_message(user, "@bot: operable:alias list \"my-*\"")
    assert "Pipeline executed successfully, but no output was returned" = response
  end

  test "list all aliases with no aliases", %{user: user} do
    response = send_message(user, "@bot: operable:alias list")
    assert "Pipeline executed successfully, but no output was returned" = response
  end

  test "list aliases with an invalid pattern", %{user: user} do
    response = send_message(user, "@bot: operable:alias list \"% &my#-*\"")

    assert_error_message_contains(response, "Whoops! An error occurred. Invalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
  end

  test "list aliases with too many wildcards", %{user: user} do
    response = send_message(user, "@bot: operable:alias list \"*my-*\"")

    assert_error_message_contains(response, "Whoops! An error occurred. Too many wildcards. You can only include one wildcard in a query")
  end

  test "list aliases with a bad pattern and too many wildcards", %{user: user} do
    response = send_message(user, "@bot: operable:alias list \"*m++%y-*\"")

    assert_error_message_contains(response, "Whoops! An error occurred. Too many wildcards. You can only include one wildcard in a query\nInvalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
  end

  test "passing too many args", %{user: user} do
    response = send_message(user, "@bot: operable:alias create my-invalid-alias \"echo foo\" invalid-arg")

    assert_error_message_contains(response, "Whoops! An error occurred. Too many args. Arguments required: exactly 2.")
  end

  test "passing too few args", %{user: user} do
    response = send_message(user, "@bot: operable:alias create my-invalid-alias")

    assert_error_message_contains(response, "Whoops! An error occurred. Not enough args. Arguments required: exactly 2.")
  end

  test "passing an unknown subcommand", %{user: user} do
    response = send_message(user, "@bot: operable:alias foo")

    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'foo'")
  end

end
