Code.load_file(Path.join([__DIR__, "config", "helpers.exs"]))

defmodule Cog.Mixfile do
  use Mix.Project

  def project do
    [app: :cog,
     version: "0.0.1",
     elixir: "~> 1.2",
     leex_options: [:warnings_as_errors],
     elixirc_options: [warnings_as_errors: System.get_env("ALLOW_WARNINGS") == nil],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     aliases: aliases]
  end

  def application do
    [applications: [:logger,
                    :probe,
                    :logger_file_backend,
                    :ibrowse,
                    :httpotion,
                    :gproc,
                    :esockd,
                    :emqttd,
                    :exml,
                    :hedwig,
                    :slack,
                    :cowboy,
                    :phoenix,
                    :phoenix_ecto,
                    :postgrex,
                    :phoenix_html,
                    :comeonin,
                    :spanner],
     mod: {Cog, []}]
  end

  defp deps do
    [
     {:slack, "~> 0.4.2"},
     {:websocket_client, github: "jeremyong/websocket_client", ref: "f6892c8b55004008ce2d52be7d98b156f3e34569"},
     {:poison, "1.5.0"},
     {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.2"},
     {:uuid, "1.0.1"},
     {:httpotion, "2.1.0"},
     {:jsx, "~> 2.8.0", override: true},
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev},
     {:mix_test_watch, "~> 0.1.1", only: :dev},
     {:postgrex, "~> 0.9.1"},
     {:ecto, "~> 1.0.0"},
     {:lager_logger, github: "PSPDFKit-labs/lager_logger", branch: "master"},
     {:logger_file_backend, github: "onkel-dirtus/logger_file_backend", tag: "v0.0.6"},
     {:emqttc, github: "emqtt/emqttc", branch: "master"},
     {:emqttd, github: "operable/emqttd", branch: "tweaks-for-upstream"},
     {:lager, ">= 2.1.0", override: true},
     {:cowboy, "~> 1.0"},
     {:phoenix, "~> 1.0.3"},
     {:phoenix_ecto, "~> 1.1"},
     {:phoenix_html, "~> 2.1"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:comeonin, "~> 1.1.2"},
     {:hedwig, "~> 0.3.0"},
     {:gproc, "~> 0.5.0", override: true},
     {:html_entities, "~> 0.2"},
     {:spanner, git: "git@github.com:operable/spanner", ref: "717edd8f450b942e861b42ea346033fdbf6edb53"},
     {:probe, git: "git@github.com:operable/probe", tag: "0.1-rc1"},
     {:exml, github: "paulgray/exml", tag: "2.2.1"},
     {:fumanchu, github: "operable/fumanchu", ref: "210bd6294d7fce3e9b651cc481496bf6d0cd4f1f"},
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end
end
