defmodule Cog.Command.OptionInterpreter do
  require Logger
  alias Cog.Command.CommandCache
  alias Piper.Command.Ast

  @truthy_values ["1", "t", "true", "y", "yes", "on"]

  def initialize(%Ast.Invocation{}=command, raw) do
    case CommandCache.fetch_options(command, :prepared) do
      :not_found ->
        :not_found
      {:ok, defs} ->
        case interpret(defs, raw, [], %{}) do
          {:ok, options, args} ->
            options = set_defaults(command, options)
            {:ok, options, args}
          error ->
            error
        end
    end
  end

  def interpret(%Ast.Invocation{}=command, options, raw) do
    case initialize(command, raw) do
      {:ok, new_options, args} ->
        options = Dict.merge(options, new_options, &merge_options/3)
        {:ok, options, args}
      error ->
        error
    end
  end

  defp merge_options(_key, v1, v2) when is_list(v1) do
    v1 ++ v2
  end
  defp merge_options(_key, v1, v2) when is_integer(v1) do
    v1 + v2
  end
  defp merge_options(_key, _v1, v2) do
    v2
  end


  defp set_defaults(%Ast.Invocation{}=command, options) do
    {:ok, defs} = CommandCache.fetch_options(command, :options)
    Enum.reduce(defs, options, &(set_default_value(&1.name, &1.option_type.name, &2)))
  end

  defp set_default_value(name, "incr", options) do
    if Map.has_key?(options, name) == false do
      Map.put(options, name, 0)
    else
      options
    end
  end
  defp set_default_value(_name, _type, options) do
    options
  end


  defp interpret(_defs, nil, args, state) do
    {:ok, state, args}
  end
  defp interpret(_defs, [], args, state) do
    {:ok, state, Enum.reverse(args)}
  end
  defp interpret(defs, [%Ast.Option{flag: flag, value: nil}=opt|t], args, state) do
    case Map.get(defs, flag) do
      nil ->
        Logger.debug("Skipping unknown flag #{flag}")
        interpret(defs, t, args, state)
      opt_def ->
        case maybe_consume_arg(opt_def.option_type.name, t) do
          {:ok, value, t} ->
            opt = %{opt | value: value}
            interpret(defs, t, args, store_option(state, opt_def, opt))
          error ->
            error
        end
    end
  end
  defp interpret(defs, [%Ast.Option{flag: flag, value: value}=opt|t], args, state) do
    case Map.get(defs, flag) do
      nil ->
        Logger.debug("Skipping unknown flag #{flag}")
        interpret(defs, t, args, state)
      opt_def ->
        case interpret_kv_option(opt_def.option_type.name, value) do
          {:ok, updated} ->
            opt = %{opt | value: updated}
            interpret(defs, t, args, store_option(state, opt_def, opt))
          error ->
            error
        end
    end
  end
  defp interpret(defs, [arg|t], args, state) do
    interpret(defs, t, [arg|args], state)
  end

  defp store_option(opts, opt_def, opt) do
    case is_map(opt.value) and Map.has_key?(opt.value, :__struct__) do
      true ->
        store_option_value(opts, opt_def, opt.value.value)
      false ->
      store_option_value(opts, opt_def, opt.value)
    end
  end

  defp store_option_value(opts, opt_def, value) do
    if opt_def.option_type.name == "incr" do
      Map.update(opts, opt_def.name, value, &(%{&1 | value: &1.value  + value}))
    else
      Map.put(opts, opt_def.name, value)
    end
  end

  defp maybe_consume_arg("incr", [%Ast.Integer{value: value}|t]) do
    {:ok, value, t}
  end
  defp maybe_consume_arg("incr", args) do
    {:ok, 1, args}
  end
  defp maybe_consume_arg("bool", args) do
    {:ok, true, args}
  end
  defp maybe_consume_arg(type, [arg|t]) do
    case interpret_kv_option(type, arg) do
      {:ok, updated} ->
        {:ok, updated, t}
      error ->
        error
    end
  end
  defp maybe_consume_arg(_type, []) do
    {:error, "Unexpected end of input."}
  end

  defp interpret_kv_option("int", value) when is_integer(value) do
    {:ok, value}
  end
  defp interpret_kv_option("int", value) when is_float(value) do
    {:error, "Type Error: '#{value}' is not of type 'int'"}
  end
  defp interpret_kv_option("int", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        {:ok, int}
      _error ->
        {:error, "Type Error: '#{value} is not of type 'int'"}
    end
  end
  defp interpret_kv_option("float", value) when is_float(value) do
    {:ok, value}
  end
  defp interpret_kv_option("float", value) when is_integer(value) do
    {:ok, value/1}
  end
  defp interpret_kv_option("float", value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rem} ->
        {:ok, float}
      :error ->
        {:error, "Type Error: '#{value}' is not of type 'float'"}
    end
  end
  defp interpret_kv_option("bool", value) when is_integer(value) do
    {:ok, value > 0}
  end
  defp interpret_kv_option("bool", value) do
    {:ok, Enum.member?(@truthy_values, value)}
  end
  defp interpret_kv_option("incr", value),
  do: interpret_kv_option("int", value)
  defp interpret_kv_option("string", value),
  do: {:ok, value}
  defp interpret_kv_option(type, value) do
    {:error, {type, value.__struct__}}
  end

end
