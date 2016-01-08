defmodule Cog.Config.Test do
  use ExUnit.Case
  alias Cog.Config

  doctest Cog.Config

  test "convert various times to seconds or milliseconds" do
    assert 1 = Config.convert({1, :sec}, :sec)
    assert 1000 = Config.convert({1, :sec}, :ms)

    assert 10000 = Config.convert({10, :sec}, :ms)

    assert 60 = Config.convert({60, :sec}, :sec)
    assert 60 = Config.convert({1, :min}, :sec)
    assert 60000 = Config.convert({1, :min}, :ms)

    assert 3600 = Config.convert({60, :min}, :sec)
    assert 3600 = Config.convert({1, :hour}, :sec)
    assert 3600000 = Config.convert({1, :hour}, :ms)

    assert 86400 = Config.convert({24, :hour}, :sec)
    assert 86400 = Config.convert({1, :day}, :sec)
    assert 86400000 = Config.convert({1, :day}, :ms)

    assert 604800 = Config.convert({7, :day}, :sec)
    assert 604800 = Config.convert({1, :week}, :sec)
    assert 604800000 = Config.convert({1, :week}, :ms)
  end



end
