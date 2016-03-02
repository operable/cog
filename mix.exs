Code.load_file(Path.join([__DIR__, "config", "helpers.exs"]))

defmodule Cog.Mixfile do
  use Mix.Project

  def project do
    [app: :cog,
     version: "0.2.0",
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
                    :exml,
                    :hedwig,
                    :slack,
                    :cowboy,
                    :phoenix,
                    :phoenix_ecto,
                    :postgrex,
                    :phoenix_html,
                    :comeonin,
                    :spanner,
                    :exirc],
     included_applications: [:emqttd],
     mod: {Cog, []}]
  end

  defp deps do
    [{:slack, "~> 0.4.2"},
     {:piper, github: "operable/piper", branch: "kevsmith/new-cmd-parser", override: true},
     {:websocket_client, github: "jeremyong/websocket_client", ref: "f6892c8b55004008ce2d52be7d98b156f3e34569"},
     {:poison, "~> 1.5.2"},
     {:ibrowse, "~> 4.2.2"},
     {:uuid, "~> 1.1.3"},
     {:httpotion, "~> 2.2.0"},
     {:jsx, "~> 2.8.0", override: true},
     {:postgrex, "~> 0.11.1"},
     {:ecto, "~> 1.1.3"},
     {:lager_logger, "~> 1.0.2"},
     {:logger_file_backend, github: "onkel-dirtus/logger_file_backend", ref: "457ce74fc242261328f71a77d75252bf0c74c170"},
     {:emqttd, github: "operable/emqttd", branch: "tweaks-for-upstream"},
     {:lager, "~> 3.0.2", override: true},
     {:cowboy, "~> 1.0.4"},
     {:phoenix, "~> 1.1.4"},
     {:phoenix_ecto, "~> 2.0.1"},
     {:phoenix_html, "~> 2.5.0"},
     {:comeonin, "~> 2.1.1"},
     {:hedwig, "~> 0.3.0"},
     {:gproc, "~> 0.5.0", override: true},
     {:html_entities, "~> 0.3.0"},
     {:spanner, github: "operable/spanner", ref: "21446f27e6eaf9b40c9ba529810c65adc17b95a2"},
     {:probe, github: "operable/probe", tag: "0.2"},
     {:exml, github: "paulgray/exml", tag: "2.2.1"},
     {:fumanchu, github: "operable/fumanchu", ref: "cog-0.2"},
     {:exirc, "~> 0.9.2"},

     {:phoenix_live_reload, "~> 1.0.3", only: :dev},
     {:earmark, "~> 0.2.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev},
     {:mix_test_watch, "~> 0.1.1", only: :test}

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
