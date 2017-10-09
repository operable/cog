defmodule Cog.Pipeline.OptionParser do
  require Logger
  alias Cog.Models.CommandOption
  alias Piper.Command.Ast

  @truthy_values ["true", "t", "y", "yes", "on"]

  def parse(%Ast.Invocation{args: args, meta: parser_meta}=invocation) do
    defs = Enum.reduce(parser_meta.options, %{}, &prepare_option/2)
    with({:ok, options, args} <- interpret(defs, args, [], %{}),
         :ok <- check_required_options(defs, options)) do
      options = set_defaults(invocation, options)
      {:ok, options, args}
    end
  end

  ########################################################################

  defp prepare_option(%CommandOption{long_flag: lflag, short_flag: nil}=opt, acc),
    do: Map.put(acc, lflag, opt)
  defp prepare_option(%CommandOption{long_flag: nil, short_flag: sflag}=opt, acc),
    do: Map.put(acc, sflag, opt)
  defp prepare_option(%CommandOption{long_flag: lflag, short_flag: sflag}=opt, acc) do
    acc
    |> Map.put(lflag, opt)
    |> Map.put(sflag, opt)
  end

  defp interpret(_defs, nil, true_args, validated_options),
    do: {:ok, validated_options, true_args}
  defp interpret(_defs, [], true_args, validated_options),
    do: {:ok, validated_options, Enum.reverse(true_args)}
  defp interpret(defs, [%Ast.Option{name: %Ast.String{value: name}, value: nil}=opt|t], true_args, validated_options) do
    case Map.fetch(defs, name) do
      {:ok, opt_def} ->
        case maybe_consume_arg(opt_def.option_type.name, t) do
          {:ok, value, t} ->
            opt = %{opt | value: value}
            interpret(defs, t, true_args, store_option(validated_options, opt_def, opt))
          error ->
            error
        end
      :error ->
        Logger.debug("Skipping unknown name #{name}")
        interpret(defs, t, true_args, validated_options)
    end
  end
  defp interpret(defs, [%Ast.Option{name: %Ast.String{value: name},
                                    value: value}=opt|t], true_args, validated_options) do
    case Map.fetch(defs, name) do
      {:ok, opt_def} ->
        case coerce_value(opt_def.option_type.name, value) do
          {:ok, coerced} ->
            opt = %{opt | value: coerced}
            interpret(defs, t, true_args, store_option(validated_options, opt_def, opt))
          error ->
            error
        end
      :error ->
        Logger.debug("Skipping unknown name #{name}")
        interpret(defs, t, true_args, validated_options)
    end
  end
  defp interpret(defs, [arg|t], true_args, validated_options),
    do: interpret(defs, t, store_arg_value(arg,true_args), validated_options)

  def store_arg_value(arg, args) when is_binary(arg) or
                                      is_integer(arg) or
                                      is_float(arg) or
                                      is_boolean(arg) do
    [arg|args]
  end
  def store_arg_value(%Ast.Variable{value: value}, args),
    do: [value|args]
  def store_arg_value(%Ast.InterpolatedString{bound: true}=interp, args) do
    [String.Chars.to_string(interp)|args]
  end
  defp set_defaults(%Ast.Invocation{}=command, options) do
    defs = command.meta.options
    Enum.reduce(defs, options, &(set_default_value(&1.name, &1.option_type.name, &2)))
  end

  defp set_default_value(name, "incr", options),
    do: Map.put_new(options, name, 0)
  defp set_default_value(_name, _type, options),
    do: options

  defp store_option(opts, opt_def, opt) do
    case is_map(opt.value) and Map.has_key?(opt.value, :__struct__) do
      true ->
        store_option_value(opts, opt_def, opt.value.value)
      false ->
        store_option_value(opts, opt_def, opt.value)
    end
  end

  defp store_option_value(opts, opt_def, value) do
    case opt_def.option_type.name do
      "incr" ->
        Map.update(opts, opt_def.name, value, &(&1+value))
      "list" ->
        Map.update(opts, opt_def.name, value, &Enum.concat(&1, value))
      _ ->
        Map.put(opts, opt_def.name, value)
    end
  end

  defp maybe_consume_arg("incr", [%Ast.Integer{value: value}|t]),
    do: {:ok, value, t}
  defp maybe_consume_arg("incr", args),
    do: {:ok, 1, args}
  defp maybe_consume_arg("bool", args),
    do: {:ok, true, args}
  defp maybe_consume_arg(_type, [%Ast.Option{}|_]),
    do: {:error, error_msg(:no_value)}
  defp maybe_consume_arg(type, [arg|t]) do
    case coerce_value(type, arg) do
      {:ok, updated} ->
        {:ok, updated, t}
      error ->
        error
    end
  end
  defp maybe_consume_arg(_type, []),
    do: {:error, "Unexpected end of input."}

  defp coerce_value(type, %Ast.Variable{value: value}),
    do: coerce_value(type, value)
  defp coerce_value(type, %Ast.InterpolatedString{}=is),
    do: coerce_value(type, to_string(is))
  defp coerce_value("int", value) when is_integer(value),
    do: {:ok, value}
  defp coerce_value("int", value) when is_float(value),
    do: {:error, error_msg(:type_error, value, "int")}
  defp coerce_value("int", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        {:ok, int}
      _error ->
        {:error, error_msg(:type_error, value, "int")}
    end
  end
  defp coerce_value("float", value) when is_float(value),
    do: {:ok, value}
  defp coerce_value("float", value) when is_integer(value),
    do: {:ok, value/1}
  defp coerce_value("float", value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rem} ->
        {:ok, float}
      :error ->
        {:error, error_msg(:type_error, value, "float")}
    end
  end
  defp coerce_value("bool", value) when is_integer(value),
    do: {:ok, value > 0}
  defp coerce_value("bool", value) when is_boolean(value),
    do: {:ok, value}
  defp coerce_value("bool", value) when is_binary(value),
    do: {:ok, Enum.member?(@truthy_values, value)}
  defp coerce_value("incr", value) do
    case coerce_value("int", value) do
      {:ok, _}=value ->
        value
      {:error, _} ->
        {:error, error_msg(:type_error, value, "incr")}
    end
  end
  defp coerce_value("string", value) when is_binary(value),
    do: {:ok, value}
  defp coerce_value("list", value) when is_binary(value) do
    # DON'T HATE
    #
    # So, we go through this regex-laden hack in order to provide an
    # expedient way to allow users to escape commas in strings that
    # they actually want to keep, and not use as string-splitting
    # boundaries.
    #
    # That is, a value of "one,two" would get converted to ["one",
    # "two"], but a value of "one\,two" would get converted to
    # ["one,two"].
    #
    # TODO: A real solution probably lies in the realm of the parser
    # and bindings.
    splits = value
    |> String.split(~r/(?<!\\),/, trim: true)
    |> Enum.map(&String.replace(&1, ~r/\\,/, ","))
    {:ok, splits}
  end
  defp coerce_value("list", value) when is_list(value),
    do: {:ok, value}
  defp coerce_value(type, value),
    do: {:error, error_msg(:type_error, value, type)}

  defp check_required_options(defs, opts) do
    required_set = defs
                   |> Enum.filter(fn({_, optdef}) -> optdef.required end)
                   |> Enum.map(fn({_, optdef}) -> optdef.name end)
                   |> Enum.uniq
                   |> MapSet.new
    input_set = opts |> Map.keys |> MapSet.new

    case MapSet.subset?(required_set, input_set) do
      true ->
        :ok
      false ->
        missing = MapSet.difference(required_set, input_set) |> MapSet.to_list
        {:error, "Looks like you forgot to include some required options: '#{Enum.join(missing, ", ")}'"}
    end
  end

  defp error_msg(:no_value), do: "No value supplied!"

  defp error_msg(:type_error, value, req_type) do
    "Type Error: `#{inspect value}` is not of type `#{req_type}`"
  end
end
