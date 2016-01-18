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
                    :erlcloud,
                    :comeonin],
     mod: {Cog, []}]
  end

  defp deps do
    [
     # Upgrade to whatever's after 0.3.0 when it's released
     {:slack, github: "BlakeWilliams/Elixir-Slack", ref: "e348e12551e8f6361d9c666ed52c83eeccce86b8"},
     {:poison, "1.5.0"},
     # Override the dependency specified by slack
     {:websocket_client, github: "kevsmith/websocket_client", override: true},
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
     {:spanner, git: "git@github.com:operable/spanner", branch: "kevsmith/descope-command-attrs"},
     {:probe, git: "git@github.com:operable/probe", ref: "02c3df4beb0332c4cab47646cfbcdf1cace1da36"},
     {:exml, github: "paulgray/exml", tag: "2.2.1"},
     {:erlcloud, github: "gleber/erlcloud", branch: "master"},
     {:fumanchu, github: "operable/fumanchu", ref: "210bd6294d7fce3e9b651cc481496bf6d0cd4f1f"},
     {:tentacat, "~> 0.2.1"} # for embedded github service
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
