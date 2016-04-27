defmodule Spanner.Command.Request do

  use Spanner.Marshalled
  alias Spanner.Config

  require Logger

  defmarshalled [:room, :requestor, :user, :command, :args, :options, :command_config, :reply_to, :cog_env]

  defp validate(request) do
    cond do
      request.room == nil ->
        {:error, {:empty_field, :room}}
      request.requestor == nil ->
        {:error, {:empty_field, :requestor}}
      request.command == nil ->
        {:error, {:empty_field, :command}}
      request.reply_to == nil ->
        {:error, {:empty_field, :reply_to}}
      true -> populate_config(request)
    end
  end

  defp populate_config(request) do
    case get_config(request) do
      {:ok, command_config} -> {:ok, %{request | command_config: command_config}}
      error -> error
    end
  end

  defp get_config(request) do
    case open_config(request) do
      :dir_not_found -> {:ok, %{}}
      {:ok, config} -> {:ok, config}
      {:not_found, cmd_config_dir} ->
        msg = "A directory exists for dynamic config, '#{cmd_config_dir}', but it contains no configs."
        Logger.warn(msg)
        {:ok, %{}}
      {:multiple_configs, config, config_path} ->
        msg = "Multiple dynamic config files exist. Using '#{config_path}'."
        Logger.warn(msg)
        {:ok, config}
      {:error, error} ->
        err = "Unable to read the command config file for the command '#{request.command}'. #{inspect error}"
        Logger.error(err)
        {:error, err}
    end
  end

  defp open_config(request) do
    case Application.get_env(:spanner, :command_config_root) do
      nil -> {:ok, ""}
      path -> read_config(request, path)
    end
  end

  defp read_config(request, config_path) do
    [bundle, _cmd] = String.split(request.command, ":", parts: 2)
    cmd_config_dir = Path.join([config_path, bundle])

    case File.dir?(cmd_config_dir) do
      true ->
        case Config.find_configs(cmd_config_dir) do
          [] ->
            # If a directory for dynamic config exists but there are no config files
            # we should warn the user
            {:not_found, cmd_config_dir}
          [config_path] ->
            Config.Parser.read_from_file(config_path)
          [config_path | _] ->
            # If multiple configs are found we should warn the user
            with {:ok, config} <- Config.Parser.read_from_file(config_path) do
              {:multiple_configs, config, config_path}
            end
        end
      false -> :dir_not_found
    end
  end

end
