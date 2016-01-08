defmodule Cog.Command.ForeignCommand.Helper do
  require Logger

  @allowed_env_keys ["USER", "LANG"]

  def execute(executable, req) do
    args = reconstruct_invocation(req)
    env = calling_env(req)
    opts = [:use_stdio, :exit_status, :binary, :hide, args: args, env: env]

    try do
      port = Port.open({:spawn_executable, executable}, opts)
      {:ok, port}
    rescue
      error ->
        {:error, error}
    end
  end

  def reconstruct_invocation(req) do
    options = for {flag, value} <- req.options,
      do: to_string(%Piper.Command.Ast.Option{flag: flag, value: value})

    options ++ req.args
  end

  def calling_env(req) do
    env = List.flatten([args_env(req), options_env(req), cog_env(req), filtered_env])

    for {key, value} <- env do
      key = String.to_char_list(key)
      value = value && String.to_char_list(value)
      {key, value}
    end
  end

  def args_env(req) do
    args = for {arg, index} <- Enum.with_index(req.args),
      do: {"COG_ARGV_#{index}", arg}

    argc = length(args) |> to_string
    [{"COG_ARGC", argc}|args]
  end

  def options_env(req) do
    options = for {name, value} <- req.options,
      name = name |> to_string |> String.upcase,
      value = to_string(value),
      do: {"COG_OPT_#{name}", value}

    keys = req.options |> Map.keys |> Enum.join(",")
    [{"COG_OPTS", keys}|options]
  end

  def cog_env(req) do
    {bundle, command} = Cog.Models.Command.split_name(req.command)

    [{"COG_BUNDLE",  bundle},
     {"COG_COMMAND", command},
     {"COG_USER",    req.requestor["handle"]},
     {"COG_ROOM",    req.room["name"]}]
  end

  defp filtered_env do
    for {key, value} <- System.get_env do
      case key in @allowed_env_keys do
        true  -> {key, value}
        false -> {key, false}
      end
    end
  end
end
