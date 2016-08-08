Application.ensure_all_started(:cog)

exclude_slack = System.get_env("TEST_SLACK") == nil
exclude_relay = System.get_env("TEST_RELAY") == nil

Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, :manual)

ExVCR.Config.cassette_library_dir("test/fixtures/cassettes")
ExVCR.Config.filter_sensitive_data("token=[^&]+", "token=xoxb-filtered-token")
ExVCR.Config.filter_sensitive_data("Bearer .*", "Bearer filtered-token")

ExUnit.start(exclude: [slack: exclude_slack, relay: exclude_relay])
