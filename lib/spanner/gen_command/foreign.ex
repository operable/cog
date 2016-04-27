defmodule Spanner.GenCommand.Foreign do
  @moduledoc """

  Cog provides a pristine environment to the executable that is called, with only `USER`, `HOME`, and `LANG`
  allowed to leak from Cog's environment. Additional environment variables may also be set in the Cog
  configuration file for inclusion in the execution environment. If any of the pass-through variables are set
  in the configuration file, those values override the inherited values from Cog's environment.

  In addition, there are a number of Cog-specific variables that are provided for all commands:

  ### Arguments

  * COG_ARGC=3
  * COG_ARGV_0="foo"
  * COG_ARGV_1="bar"
  * COG_ARGV_2="baz"

  ### Options

  * COG_OPTS="verbose,force,id"
  * COG_OPT_VERBOSE="true"
  * COG_OPT_FORCE="true"
  * COG_OPT_ID="123"

  ### Other Variables

  * COG_BUNDLE="operable"
  * COG_COMMAND="my_script"
  * COG_CHAT_HANDLE="imbriaco"
  * COG_PIPELINE_ID="374643c4-3f48-4e60-8c4f-671e3a11c06b"
  """

  import Spanner.GenCommand.Util, only: [format_error_message: 3]
  require Logger

  @behaviour Spanner.GenCommand

  # Keep these env vars from the runtime environment
  @propagated_vars ["HOME", "LANG", "USER"]

  # Reserve these environment keys prefixes and disallow injectable config for them
  @reserved_env_prefixes ["COG_"]
  @installed_path "$INSTALL_PATH"

  @json_format "JSON\n"
  @json_format_length String.length(@json_format)

  defstruct [:bundle, :bundle_dir, :command, :executable,
             :executable_args, :base_env]

  def init(args) do
    env_overlays = Keyword.get(args, :env, %{})
    bundle_dir = Keyword.fetch!(args, :bundle_dir)
    {:ok, %__MODULE__{bundle:  Keyword.fetch!(args, :bundle),
                      bundle_dir: bundle_dir,
                      command: Keyword.fetch!(args, :command),
                      executable: Keyword.fetch!(args, :executable),
                      base_env: build_base_environment(env_overlays, bundle_dir),
                      executable_args: Keyword.get(args, :executable_args, [])}}
  end

  def handle_message(request, %__MODULE__{executable: exe, bundle_dir: bundle_dir, base_env: base}=state) do
    calling_env = Map.to_list(Map.merge(base, build_calling_env(request, state)))
    command_input = build_stdin(request.cog_env)
    opts = [in: command_input, out: :string, err: :string, dir: bundle_dir, env: calling_env]

    result =
      case Application.get_env(:porcelain, :driver_internal) do
        Porcelain.Driver.Goon ->
          goon_exec(exe, opts)
        _ ->
          basic_exec(exe, get_pipeline_id(request), opts)
      end

    send_reply(request, result, state)
  end

  defp basic_exec(exe, pipeline_id, opts) do
    stdin_file = Path.join([opts[:dir], pipeline_id <> ".stdin"]) |> Path.expand
    safe_exe = sanitize_executable(exe)
    command_line = Enum.join([safe_exe, "<", stdin_file], " ")

    try do
      File.open(stdin_file, [:write], fn(file) -> IO.write(file, opts[:in]) end)
      Porcelain.shell(command_line, Dict.delete(opts, :in))
    after
      File.rm(stdin_file)
    end
  end

  defp goon_exec(exe, opts) do
    Porcelain.exec(exe, [], opts)
  end

  defp send_reply(request, %Porcelain.Result{status: 0, out: out}, state) do
    out = process_log_statements(out, state.command)
    case parse_output(out, state.command) do
      {template, {:ok, content}} ->
        {:reply, request.reply_to, template, content, state}
      {_template, {:error, message}} ->
        {:error, request.reply_to, message, state}
      {:ok, content} ->
        {:reply, request.reply_to, content, state}
      {:error, message} ->
        {:error, request.reply_to, message, state}
    end
  end
  defp send_reply(request, %Porcelain.Result{err: err, out: out}, state) do
    process_log_statements(out, state.command)
    {_, message} = parse_output(err, state.command)
    {:error, request.reply_to, message, state}
  end
  defp send_reply(request, error, state) do
    # Note that we currently can use `System.stacktrace/0` here only
    # because Porcelain (from whence the error will come) internally
    # catches errors and turns them into error tuples, which is what
    # we get here.
    #
    # `System.stacktrace/0` returns the stacktrace of the last
    # exception, not the current stacktrace.
    message = format_error_message(request.command, error, System.stacktrace)
    {:error, request.reply_to, message, state}
  end
  defp parse_output(text, command_name) do
    case Regex.run(~r/^COG_TEMPLATE: ([a-zA-Z0-9_\.])+\n/, text, capture: :first) do
      nil ->
        parse_content(text, command_name)
      [raw_template_name] ->
        {_, content} = String.split_at(text, String.length(raw_template_name))
        [_, template_name] = String.split(raw_template_name, ": ")
        {String.strip(template_name), parse_content(content, command_name)}
    end
  end

  defp parse_content(text, command_name) do
    text = String.strip(text)
    |> process_log_statements(command_name)
    if String.starts_with?(text, @json_format) do
      raw_json = String.slice(text, @json_format_length..(String.length(text)))
      case Poison.decode(raw_json) do
        {:ok, json} ->
          {:ok, json}
        _error ->
          {:error, "Command returned invalid json: #{inspect raw_json}"}
      end
    else
      {:ok, text}
    end
  end

  defp process_log_statements(text, command_name)
  defp process_log_statements(nil, _) do
    nil
  end
  defp process_log_statements(text, command_name) do
    process_log_statements(String.split(text, "\n"), [], command_name)
  end

  defp process_log_statements([], [], _command_name) do
    ""
  end
  defp process_log_statements([], remaining, _command_name) do
    Enum.join(Enum.reverse(remaining), "\n")
  end
  defp process_log_statements([<<"COGCMD_", log_message::binary>>|t], remaining, command_name) do
    write_to_log(log_message, command_name)
    process_log_statements(t, remaining, command_name)
  end
  defp process_log_statements([h|t], remaining, command_name) do
    process_log_statements(t, [h|remaining], command_name)
  end

  defp write_to_log(<<"DEBUG:", message::binary>>, command_name) do
    Logger.debug("From Cog command #{command_name}: #{String.strip(message)}")
  end
  defp write_to_log(<<"INFO:", message::binary>>, command_name) do
    Logger.info("From Cog command #{command_name}: #{String.strip(message)}")
  end
  defp write_to_log(<<"WARN:", message::binary>>, command_name) do
    Logger.warn("From Cog command #{command_name}: #{String.strip(message)}")
  end
  defp write_to_log(<<"ERR:", message::binary>>, command_name) do
    Logger.error("From Cog command #{command_name}: #{String.strip(message)}")
  end
  defp write_to_log(_, _) do
    :ok
  end

  defp build_base_environment(overlays, bundle_dir) do
    base_env = System.get_env()
    |> Enum.map(&filter_env(&1))
    |> :maps.from_list

    updated = overlays
    |> Enum.map(fn({key, value}) -> {String.upcase(key), maybe_bundle_dir(value, bundle_dir)} end)
    |> :maps.from_list

    Map.merge(base_env, updated)
  end

  defp maybe_bundle_dir(value, bundle_dir) do
    String.replace(value, ~r/\$INSTALL_PATH/, bundle_dir)
  end

  defp build_calling_env(request, %__MODULE__{bundle: bundle, command: command, bundle_dir: bundle_dir}) do
    %{"COG_BUNDLE" => bundle,
      "COG_COMMAND" => command,
      "COG_PIPELINE_ID" => get_pipeline_id(request)}
    |> Map.merge(build_args_vars(request.args))
    |> Map.merge(build_options_vars(request.options))
    |> Map.merge(filter_injectable_config(request.command_config, bundle_dir))
    |> Map.merge(build_trigger_vars(request.requestor))
    |> Map.merge(build_chat_vars(request.requestor))
  end

  defp build_args_vars([]) do
    %{"COG_ARGC" => "0"}
  end
  defp build_args_vars(args) do
    acc = %{"COG_ARGC" => Integer.to_string(length(args))}
    Enum.reduce(Enum.with_index(args), acc,
      fn({value, index}, acc) ->
        Map.put(acc, "COG_ARGV_#{index}", "#{value}")
      end)
  end

  defp build_options_vars(options) do
    opt_names = Enum.join(Map.keys(options), ",")
    acc = %{"COG_OPTS" => "\"#{opt_names}\""}
    Enum.reduce(options, acc,
      fn({key, value}, acc) ->
        Map.put(acc, "COG_OPT_#{String.upcase(key)}", "#{value}")
      end)
  end

  defp build_trigger_vars(requestor) do
    Enum.reduce(["trigger_id", "trigger_name", "trigger_user"], %{},
      fn(key, acc) ->
        case Map.fetch(requestor, key) do
          {:ok, value} ->
            Map.put(acc, "COG_#{String.upcase(key)}", inspect(value))
          :error ->
            acc
        end
      end)
  end

  defp build_chat_vars(requestor) do
    Enum.reduce(["handle"], %{},
      fn(key, acc) ->
        case Map.fetch(requestor, key) do
          {:ok, value} ->
            Map.put(acc, "COG_CHAT_#{String.upcase(key)}", inspect(value))
          :error ->
            acc
        end
      end)
  end

  defp filter_injectable_config(config_map, bundle_dir) do
    Enum.filter(config_map, fn({k,_v}) -> String.starts_with?(k, @reserved_env_prefixes) == false end)
    |> Enum.map(fn({key, value}) -> {String.upcase(key), maybe_bundle_dir(value, bundle_dir)} end)
    |> Enum.into(%{})
  end

  defp get_pipeline_id(request) do
    request.reply_to
    |> String.split("/")
    |> Enum.at(3)
  end

  defp filter_env({key, value}) when key in @propagated_vars do
    {key, value}
  end
  defp filter_env({key, _}), do: {key, false}

  defp build_stdin([]), do: nil
  defp build_stdin(map) when is_map(map) and map_size(map) == 0, do: nil
  defp build_stdin([map]) when is_map(map) and map_size(map) == 0, do: nil
  defp build_stdin(env) when is_map(env) or is_list(env), do: Poison.encode!(env)
  defp build_stdin(_), do: nil

  # Strip any single quotes from the executable name, then wrap it in single quotes
  # as a final barrier to prevent shell metacharacters from sneaking in.
  defp sanitize_executable(exe) do
    "'" <> String.replace(exe, "'", "") <> "'"
  end
end
