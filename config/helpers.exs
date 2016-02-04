defmodule Cog.Config.Helpers do
  defmacro __using__(_) do
    quote do
      import Cog.Config.Helpers
    end
  end

  defmacro data_dir do
    System.get_env("COG_DATA_DIR") || Path.expand(Path.join([Path.dirname(__ENV__.file), ".."]))
  end

  defmacro data_dir(subdir) do
    Path.join([data_dir, subdir])
  end
end
