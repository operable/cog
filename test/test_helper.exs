Application.ensure_all_started(:cog)

Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, :manual)

ExUnit.start()
