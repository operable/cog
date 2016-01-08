defmodule Cog.TokenReaper.Test do
  use Cog.ModelCase

  @reap_period 1 * 1000 # milliseconds
  @ttl         1 # seconds

  setup do
    {:ok, reaper} = GenServer.start_link(Cog.TokenReaper, [@reap_period, @ttl])
    on_exit(fn() -> :erlang.exit(reaper, :ok) end)

    user_with_tokens = user("cog")
    |> with_token
    |> with_token
    |> with_token

    {:ok, [user: user_with_tokens]}
  end

  test "reaper reaps tokens", %{user: user} do
    pre_reap = user |> Repo.preload(:tokens)
    assert length(pre_reap.tokens) == 3

    :timer.sleep(@reap_period + 1000) # let reaper kick in

    post_reap = user |> Repo.preload(:tokens)
    assert length(post_reap.tokens) == 0
  end

end
