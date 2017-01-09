defmodule Cog.Command.Service.DataStore.NestedFile do
  @moduledoc """
  Stores an arbitrary String on the filesystem of the Cog host in a file
  named by combining the provided key and extension. Files are written to
  a directory hierarchy that is created by splitting the filename into
  two character segments and joining up to three of those segments with a
  provided list of base path segments.

  Note: The key is sanitized to remove dangerous characters, but the
  base paths and extension are not. Make sure not to use user entered
  values for these unsafe arguments.

  Example: If the replace function was called with the following options:

  base_paths = [ "commands", "tee" ]
  key = "myfilename/../foo"
  ext = "json"

  The following would be created on disk:

  .
  └── commands
      └── tee
          └── my
              └── fi
                  └── le
                      └── myfilenamefoo.json

  This directory structure is created in order to deal with the fact that
  some filesystems demonstrate poor performance characteristics when working
  with directories that contain a very large number of files.
  """
  require Logger

  def fetch(base_paths, key, ext \\ "data") do
    case File.read(build_filename(base_paths, key, ext)) do
      {:error, reason} ->
        {:error, error_text(reason)}
      {:ok, content} ->
        {:ok, content}
    end
  end

  def replace(base_paths, key, content, ext \\ "data") do
    filename = build_filename(base_paths, key, ext)
    File.mkdir_p(Path.dirname(filename))

    case File.write(filename, content) do
      {:error, reason} ->
        {:error, error_text(reason)}
      :ok ->
        {:ok, content}
    end
  end

  def delete(base_paths, key, ext \\ "data") do
    case File.rm(build_filename(base_paths, key, ext)) do
      {:error, reason} ->
        {:error, error_text(reason)}
      :ok ->
        :ok
    end
  end

  defp error_text(:enoent), do: "Object not found"
  defp error_text(:enospc), do: "No space available to save object"
  defp error_text(:eacces), do: "Permission denied"
  defp error_text(reason) do
    "E_" <> (Atom.to_string(reason) |> String.slice(1..-1) |> String.upcase)
  end

  defp build_filename(base_paths, key, ext) do
    key = sanitize_filename(key)

    segments =
      Regex.scan(~r/.{1,2}/, key)
      |> List.flatten
      |> Enum.slice(0,3)
    filename = key <> "." <> ext
    Path.join(base_paths ++ segments ++ [filename])
  end

  defp sanitize_filename(name) do
    Regex.replace(~r/[^A-Za-z0-9_\-]/, name, "", global: true)
  end
end
