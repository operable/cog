Code.load_file(Path.join([__DIR__, "config", "helpers.exs"]))

defmodule Cog.Mixfile do
  use Mix.Project

  def project do
    [app: :cog,
     version: "0.13.0",
     elixir: "~> 1.3.1",
     erlc_paths: ["emqttd_plugins"],
     erlc_options: [:debug_info, :warnings_as_errors],
     elixirc_options: [warnings_as_errors: System.get_env("ALLOW_WARNINGS") == nil,
                       long_compilation_threshold: 50],
     consolidate_protocols: Mix.env == :prod,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     aliases: aliases,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test,
                         "coveralls.html": :test,
                         "coveralls.post": :test]
    ]
  end

  def application do
    [applications: started_applications,
     included_applications: [:emqttd],
     mod: {Cog, []}]
  end

  defp started_applications do
    apps = [:lager,
            :logger,
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
            :exirc]
    if System.get_env("COG_SASL_LOG") != nil do
      [:sasl|apps]
    else
      apps
    end
  end

  defp deps do
    [{:slack, github: "BlakeWilliams/Elixir-Slack"},
     {:websocket_client, github: "jeremyong/websocket_client"},
     {:poison, "~> 2.0"},
     {:ibrowse, "~> 4.2.2", override: true},
     {:uuid, "~> 1.1.3"},
     {:httpotion, "~> 3.0.0", override: true},
     {:jsx, "~> 2.8.0", override: true},
     {:postgrex, "~> 0.11.2"},
     {:ecto, "~> 2.0.2"},
     {:lager_logger, "~> 1.0.2"},
     {:logger_file_backend, github: "onkel-dirtus/logger_file_backend"},
     {:gen_logger, github: "emqtt/gen_logger", branch: "master", override: true},
     {:esockd, github: "emqtt/esockd", ref: "e6c27801bb5331d064081ef6d6af291a2878038c", override: true},
     {:emqttc, github: "emqtt/emqttc", branch: "master"},
     {:emqttd, github: "emqtt/emqttd", tag: "1.1.2"},
     {:lager, "~> 3.0.2", override: true},
     {:cowboy, "~> 1.0.4"},
     {:phoenix, "~> 1.1.4"},
     {:phoenix_ecto, "~> 3.0.0"},
     {:phoenix_html, "~> 2.6.0"},
     {:comeonin, "~> 2.1.1"},
     {:hedwig, "~> 0.3.0"},
     {:gproc, "~> 0.5.0", override: true},
     {:html_entities, "~> 0.3.0"},
     {:adz, github: "operable/adz"},
     {:spanner, github: "operable/spanner"},
     {:probe, github: "operable/probe"},
     {:exml, github: "paulgray/exml", tag: "2.2.1"},
     {:fumanchu, github: "operable/fumanchu"},
     {:exirc, "~> 0.9.2"},
     {:exjsx, "~> 3.2", override: true},
     {:bamboo_smtp, "~> 1.2.0"},
     # Overriding httpoison here because bamboo depends on 0.9 but slack has
     # the dep locked at 0.8.3
     {:httpoison, "~> 0.9", override: true},
     {:conduit, github: "operable/conduit", branch: "cm/tweaks"},

     {:credo, "~> 0.3", only: [:dev, :test]},
     {:phoenix_live_reload, "~> 1.0.3", only: :dev},
     {:earmark, "~> 0.2.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev},
     {:mix_test_watch, "~> 0.1.1", only: [:test, :dev]},
     {:excoveralls, "~> 0.5", only: :test},
     {:exvcr, "~> 0.7.3", only: [:dev, :test]}
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
