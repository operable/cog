defmodule Cog.Template.EngineTest do
  use ExUnit.Case

  require Logger

  alias Cog.Template.Engine.ForbiddenElixirError
  alias Cog.Template.Engine.ForbiddenErlangError

  # Helper for now; eventually, this would actually be part of Cog itself
  defp render(template, assigns \\ %{}),
    do: EEx.eval_string(template, [assigns: assigns], [engine: Cog.Template.Engine, trim: true])

  test "basic assigns works" do
    rendered = render("The result is: <%= @foo %>", %{foo: "Hello World"})
    assert "The result is: Hello World" = rendered
  end

  test "Can't '.' invoke a function from another module (top level)" do
    assert_raise(ForbiddenElixirError, fn ->
      render("<%= String.upcase(@foo) %>", %{foo: "Hello World"})
    end)
  end

  test "Can't '.' invoke a function from another module (nested)" do
    assert_raise(ForbiddenElixirError, fn ->
      render("<%= inspect(String.upcase(@foo)) %>", %{foo: "Hello World"})
    end)
  end

  test "can invoke helper function at top level" do
    rendered = render("A list: <%= join(@foo, \", \") %>",
                      %{foo: ["one", "two", "three"]})
    assert "A list: one, two, three" == rendered
  end

  test "can invoke helper (nested)" do
    rendered = render("A nested list: <%= join([join(@foo, \"-\"), \"blah\"], \"***\") %>",
                      %{foo: ["one", "two", "three"]})
    assert "A nested list: one-two-three***blah" == rendered
  end

  test "can't call an Erlang function" do
    assert_raise(ForbiddenErlangError, fn ->
      render("<%= :code.priv_dir(:cog) %>")
    end)
  end

  test "we can use if!" do
    rendered = render("""
    <%= if @thing == "foo" do %>
    I'm a foo
    <% else %>
    I'm not a foo, I'm something else
    <% end %>
    """, %{thing: "bar"})

    assert """
    I'm not a foo, I'm something else
    """ == rendered
  end

  test "need to ensure that we don't accidentally wipe out code responsible for rendering the templates" do
    rendered = render("""
    <%= if @thing == "foo" do %>
    I'm a foo
    <% else %>
    I'm not a foo, I'm a <%= @thing %>
    <% end %>
    """, %{thing: "bar"})

    assert """
    I'm not a foo, I'm a bar
    """ == rendered

  end

  test "can't exit!" do
    assert_raise(ForbiddenElixirError, fn ->
      render("<%= exit(:normal) %>")
    end)
  end

  test "can create variables" do
    rendered = render("""
    <% x = @foo %>
    x is <%= x %>
    x is also <%= x %>
    """, %{foo: "blah"})

    assert """
    x is blah
    x is also blah
    """ == rendered
  end

  test "can reach into nested assigns" do
    rendered = render("<%= @foo.bar.baz %>",
                      %{foo: %{bar: %{baz: "Hello"}}})
    assert "Hello" == rendered
  end

  test "can't import arbitrary code" do
    assert_raise(ForbiddenElixirError,
      fn() -> render("""
      <% import Cog.UUID %>
      <%= is_uuid?("nope") %>
      """)
      end)
  end

  test "can't require arbitrary code" do
    assert_raise(ForbiddenElixirError,
      fn() ->
        render("<%= require Logger %>")
      end)
  end

  test "can't use arbitrary code" do
    assert_raise(ForbiddenElixirError,
      fn() ->
        render("<%= use GenServer %>")
      end)
  end

  test "can use a for loop" do
    rendered = render("""
    <%= for x <- @foo do %>
      * <%= x %>
    <% end %>
    """, %{foo: [1, 2, 3]})

    assert """
      * 1
      * 2
      * 3
    """ == rendered
  end

  test "can match a regex (but note the escaping)" do
    rendered = render("""
    * <%= @foo =~ ~r/\\d+/ %>
    * <%= @bar =~ ~r/\\d+/ %>
    """, %{foo: "123", bar: "nope"})

    assert """
    * true
    * false
    """ == rendered
  end

end
