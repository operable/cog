Code.load_file(Path.join([__DIR__, "config", "helpers.exs"]))

defmodule Cog.Mixfile do
  use Mix.Project

  def project do
    [app: :cog,
     version: "0.14.0",
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
            :slack,
            :cowboy,
            :phoenix,
            :phoenix_ecto,
            :postgrex,
            :phoenix_html,
            :comeonin,
            :spanner,
            :bamboo]
    if System.get_env("COG_SASL_LOG") != nil do
      [:sasl|apps]
    else
      apps
    end
  end

  defp deps do
    [
      # Operable Code
      ########################################################################
      {:adz, github: "operable/adz"},
      {:conduit, github: "operable/conduit"},
      {:fumanchu, github: "operable/fumanchu"},
      {:probe, github: "operable/probe"},
      {:spanner, github: "operable/spanner"},

      # MQTT-related
      ########################################################################
      {:emqttc, github: "emqtt/emqttc", branch: "master"},
      {:emqttd, github: "emqtt/emqttd", tag: "1.1.2"},
      {:esockd, github: "emqtt/esockd", ref: "e6c27801bb5331d064081ef6d6af291a2878038c", override: true},
      {:gen_logger, github: "emqtt/gen_logger", branch: "master", override: true},
      # Used by cowboy, emqttd, esockd... they don't seem to lock to a
      # particular version, though.
      {:gproc, "~> 0.5.0", override: true},

      # Logging
      ########################################################################
      # lager_logger depends on lager, but is using an old version
      {:lager, "~> 3.0.2", override: true},
      {:lager_logger, "~> 1.0.3"},
      {:logger_file_backend, github: "onkel-dirtus/logger_file_backend"},

      # Other Direct Dependencies
      ########################################################################
      {:bamboo_smtp, "~> 1.2.0"},
      {:comeonin, "~> 2.5"},
      {:cowboy, "~> 1.0.4"},
      {:ecto, "~> 2.0.2"},
      {:html_entities, "~> 0.3.0"},
      # Bamboo depends httpoison 0.9 but slack has the dep locked at
      # 0.8.3
      {:httpoison, "~> 0.9", override: true},
      {:httpotion, "~> 3.0"},
      {:phoenix, "~> 1.2"},
      {:phoenix_ecto, "~> 3.0"},
      {:phoenix_html, "~> 2.6"},
      {:poison, "~> 2.0"},
      {:postgrex, "~> 0.11.2"},
      {:slack, "~> 0.7.0"},
      {:uuid, "~> 1.1.3"},
      # The Slack library depends on this Github repo, and not the
      # version in Hex. Thus, we need to declare it manually :(
      {:websocket_client, github: "jeremyong/websocket_client"},

      # Test and Development
      ########################################################################
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.13", only: :dev},
      {:excoveralls, "~> 0.5", only: :test},
      {:exvcr, "~> 0.8", only: [:dev, :test]},
      {:mix_test_watch, "~> 0.2", only: [:dev, :test]},
      {:phoenix_live_reload, "~> 1.0", only: :dev}
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
