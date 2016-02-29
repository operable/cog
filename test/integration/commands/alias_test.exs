defmodule Integration.Commands.AliasTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Repo
  alias Cog.Integration.Helpers

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "creating a new alias", %{user: user} do
    expected_map = %{"name" => "my-new-alias", "pipeline" => "echo My New Alias", "visibility" => "user"}

    response = send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    expected_response = Helpers.render_template("alias-new", expected_map)
    assert response["data"]["response"] == expected_response

    new_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-new-alias", user_id: user.id)
    assert new_alias.name == expected_map["name"]
    assert new_alias.pipeline == expected_map["pipeline"]
    assert new_alias.visibility == expected_map["visibility"]
  end

  test "creating a new alias with an existing name", %{user: user} do
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. The alias name is already in use."
  end

  test "removing an alias", %{user: user} do
    expected_map = %{"name" => "my-new-alias", "pipeline" => "echo My New Alias", "visibility" => "user"}
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias rm my-new-alias")
    expected_response = Helpers.render_template("alias-rm", expected_map)
    assert response["data"]["response"] == expected_response

    assert Repo.get_by(Cog.Models.UserCommandAlias, name: "my-new-alias", user_id: user.id) == nil
  end

  test "removing an alias that does not exist", %{user: user} do
    response = send_message(user, "@bot: operable:alias rm my-new-alias")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. I can't find 'my-new-alias'. Please try again"
  end

  test "moving an alias to site using full visibility syntax", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"},
                "destination" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv user:my-new-alias site")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.SiteCommandAlias, name: "my-new-alias")
    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to site using full visibility syntax and rename", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv user:my-new-alias site:my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.SiteCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to site with short syntax", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"},
                "destination" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv my-new-alias site")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.SiteCommandAlias, name: "my-new-alias")
    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to site with short syntax and rename", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv my-new-alias site:my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.SiteCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to user with full visibility syntax", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"},
                "destination" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias mv site:my-new-alias user")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-new-alias")
    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to user with full visibility syntax and rename", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias mv site:my-new-alias user:my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to user with short syntax", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"},
                "destination" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias mv my-new-alias user")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-new-alias")
    assert command_alias.name == "my-new-alias"
  end

  test "moving an alias to user with short syntax and rename", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias mv my-new-alias user:my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "renaming an alias in the user visibility", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "user"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv my-new-alias my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.UserCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "renaming an alias in the site visibility", %{user: user} do
    expected_map = %{"source" => %{"name" => "my-new-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"},
                "destination" => %{"name" => "my-renamed-alias",
                                   "pipeline" => "echo My New Alias",
                                   "visibility" => "site"}}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias mv my-new-alias my-renamed-alias")
    expected_response = Helpers.render_template("alias-mv", expected_map)
    assert response["data"]["response"] == expected_response

    command_alias = Repo.get_by(Cog.Models.SiteCommandAlias, name: "my-renamed-alias")
    assert command_alias.name == "my-renamed-alias"
  end

  test "moving an alias to site when an alias with that name already exists in site", %{user: user} do
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv user:my-new-alias site")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. The alias name is already in use."
  end

  test "moving an alias to user when an alias with that name already exists in user", %{user: user} do
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias mv site:my-new-alias user")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. The alias name is already in use."
  end

  test "an alias in the 'user' visibility should return 'user'", %{user: user} do
    expected_map = %{"visibility" => "user"}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:alias which my-new-alias")
    expected_response = Helpers.render_template("alias-which", expected_map)
    assert response["data"]["response"] == expected_response
  end

  test "an alias in the 'site' visibility should return 'site'", %{user: user} do
    expected_map = %{"visibility" => "site"}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:alias which my-new-alias")
    expected_response = Helpers.render_template("alias-which", expected_map)
    assert response["data"]["response"] == expected_response
  end

  test "list all aliases", %{user: user} do
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new my-new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new my-new-alias2 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new my-new-alias3 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    alias_list = [%{"visibility" => "user",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias1"},
                  %{"visibility" => "user",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias2"},
                  %{"visibility" => "user",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias3"},
                  %{"visibility" => "site",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias"}]

    response = send_message(user, "@bot: operable:alias ls")
    expected_response = Helpers.render_template("alias-ls", Enum.sort(alias_list))
    assert response["data"]["response"] == expected_response
  end

  test "list all aliases matching a pattern", %{user: user} do
    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new my-new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias new new-alias1 \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    alias_list = [%{"visibility" => "site",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias"},
                  %{"visibility" => "user",
                    "pipeline" => "echo My New Alias",
                    "name" => "my-new-alias1"}]

    response = send_message(user, "@bot: operable:alias ls \"my-*\"")
    expected_response = Helpers.render_template("alias-ls", Enum.sort(alias_list))
    assert response["data"]["response"] == expected_response
  end

  test "list all aliases with no matching aliases", %{user: user} do
    alias_list = []

    response = send_message(user, "@bot: operable:alias ls \"my-*\"")
    expected_response = Helpers.render_template("alias-ls", Enum.sort(alias_list))
    assert response["data"]["response"] == expected_response
  end

  test "list all aliases with no aliases", %{user: user} do
    alias_list = []

    response = send_message(user, "@bot: operable:alias ls")
    expected_response = Helpers.render_template("alias-ls", alias_list)
    assert response["data"]["response"] == expected_response
  end

  test "list aliases with an invalid pattern", %{user: user} do
    response = send_message(user, "@bot: operable:alias ls \"% &my#-*\"")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Invalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _"
  end

  test "list aliases with too many wildcards", %{user: user} do
    response = send_message(user, "@bot: operable:alias ls \"*my-*\"")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Too many wildcards. You can only include one wildcard in a query"
  end

  test "list aliases with a bad pattern and too many wildcards", %{user: user} do
    response = send_message(user, "@bot: operable:alias ls \"*m++%y-*\"")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Too many wildcards. You can only include one wildcard in a query\nInvalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _"
  end

  test "passing too many args", %{user: user} do
    response = send_message(user, "@bot: operable:alias new my-invalid-alias \"echo foo\" invalid-arg")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Too many args. Arguments required: exactly 2."
  end

  test "passing too few args", %{user: user} do
    response = send_message(user, "@bot: operable:alias new my-invalid-alias")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Not enough args. Arguments required: exactly 2."
  end

  test "passing an unknown subcommand", %{user: user} do
    response = send_message(user, "@bot: operable:alias foo")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. Unknown subcommand 'foo'"
  end

  test "passing now subcommand", %{user: user} do
    response = send_message(user, "@bot: operable:alias")
    assert response["data"]["response"] == "@vanstee Whoops! An error occurred. I don't what to do, please specify a subcommand"
  end

end
