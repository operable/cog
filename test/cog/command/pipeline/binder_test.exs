defmodule Cog.Command.Pipeline.Binder.Test do
  use ExUnit.Case

  alias Cog.Command.Pipeline.Binder
  alias Cog.Models.Command
  alias Piper.Command.Ast

  import Cog.ExecutorHelpers, only: [unbound_invocation: 1]


  test "bind works with empty binding scope" do
    invocation =  unbound_invocation("ec2 --tags=foo")
    {:ok, bound} = Binder.bind(invocation, %{})
    assert %Piper.Command.Ast.Invocation{args: [%Piper.Command.Ast.Option{name: %Piper.Command.Ast.String{col: 7, line: 1, value: "tags"}, opt_type: :long, value: "foo"}],
                                         meta: %Command{name: "ec2"},
                                         name: %Piper.Command.Ast.Name{bundle: %Piper.Command.Ast.String{col: 1, line: 1, value: "test-bundle"},
                                                                       entity: %Piper.Command.Ast.String{col: 1, line: 1, value: "ec2"}}, redir: nil} = bound
  end

  test "bind succeeds" do
    {:ok, bound} = "ec2 --tags=$tag"
    |> unbound_invocation
    |> Binder.bind(%{"tag" => "monkey"})

    assert %Ast.Invocation{args: [
                              %Ast.Option{name: %Ast.String{col: 7, line: 1, value: "tags"},
                                          opt_type: :long,
                                          value: %Ast.Variable{col: 12, line: 1 , name: 'tag', value: "monkey"}}
                            ],
                           meta: %Command{name: "ec2"},
                           name: %Piper.Command.Ast.
                           Name{bundle: %Piper.Command.Ast.String{col: 1, line: 1, value: "test-bundle"},
                                entity: %Piper.Command.Ast.String{col: 1, line: 1, value: "ec2"}},
                           redir: nil} = bound
  end

  test "bind fails if matching option value variable isn't in scope" do
    result = "ec2 --tags=$tag"
    |> unbound_invocation
    |> Binder.bind(%{"not_a_tag" => "monkey"})

    assert result == {:error, {:missing_key, "tag"}}
  end

  test "bind fails if matching argument variable isn't in scope" do
    result = "ec2 $tag"
    |> unbound_invocation
    |> Binder.bind(%{"not_a_tag" => "monkey"})

    assert result == {:error, {:missing_key, "tag"}}
  end

end
