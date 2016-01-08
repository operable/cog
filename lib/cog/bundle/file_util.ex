defmodule Cog.Bundle.FileUtil do

  @doc """
  Recursively traverse a directory structure and return a list of file
  paths, relative to `root`.
  """
  def file_list(root) do
    unless File.exists?(root), do: raise "#{root} is not a file!"
    unless File.dir?(root), do: raise "#{root} is not a directory!"

    {:ok, files_in_root} = File.ls(root)

    {dirs, files} = files_in_root
    |> Enum.map(&("#{root}/#{&1}"))
    |> Enum.partition(&File.dir?/1)

    dir_files = Enum.flat_map(dirs, &file_list(&1))
    Enum.sort(dir_files ++ files)
  end

end
