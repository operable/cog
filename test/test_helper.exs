Application.ensure_all_started(:cog)

Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, :manual)

ExVCR.Config.cassette_library_dir("test/fixtures/cassettes")
ExVCR.Config.filter_sensitive_data("token=[^&]+", "token=xoxb-filtered-token")
ExVCR.Config.filter_sensitive_data("Bearer .*", "Bearer filtered-token")

ExUnit.start()
