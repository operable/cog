defmodule Mix.Tasks.Cog.Embedded do
  use Mix.Task

  @config_file "config/embedded_bundle_version.exs"

  @shortdoc "Bump embedded bundle version if required"

  def run(_args) do
    bundle_files
    |> Enum.map(&md5/1)
    |> hash_all
    |> maybe_update_checksum
  end

  defp bundle_files do
    beams = Path.wildcard("#{Mix.Project.compile_path}/**/Elixir.Cog.Commands.*.beam")
    templates = Path.wildcard("priv/**/*.mustache")
    Enum.sort(templates ++ beams)
  end

  defp md5(file) do
    contents = File.read!(file)
    case Path.extname(file) do
      ".beam" ->
        {:ok, {_module, md5}} = :beam_lib.md5(contents)
        md5
      ".mustache" ->
        :crypto.hash(:md5, contents)
    end
  end

  defp hash_all(md5_sums) do
    md5_sums
    |> Enum.reduce(:crypto.hash_init(:md5), &(:crypto.hash_update(&2, &1)))
    |> :crypto.hash_final
    |> Base.encode16(case: :lower)
  end

  defp maybe_update_checksum(new_checksum) do
    old_checksum       = Application.fetch_env!(:cog, :embedded_bundle_checksum)
    {:ok, old_version} = Application.fetch_env!(:cog, :embedded_bundle_version) |> Version.parse

    if new_checksum == old_checksum do
      :ok
    else
      new_version = %{old_version | patch: old_version.patch + 1}

      File.write!(@config_file,
      """
      use Mix.Config

      config :cog, :embedded_bundle_checksum, "#{new_checksum}"
      config :cog, :embedded_bundle_version, "#{new_version}"
      """)

      Mix.shell.info("""
      Embedded command bundle files have changed!

      Old Checksum = #{old_checksum}
      New Checksum = #{new_checksum}

      Old Bundle Version     = #{old_version}
      Updated Bundle Version = #{new_version}

      New data has been written to `config/embedded_bundle_version.exs`;
      please be sure to commit it!
      """)

      # Make the changes "live" for any tasks that happen to run after
      # this one.
      @config_file
      |> Mix.Config.read!
      |> Mix.Config.persist

    end
  end

end
