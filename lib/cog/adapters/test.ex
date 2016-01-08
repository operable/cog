defmodule Cog.Adapters.Test do
  import Supervisor.Spec

  @behaviour Cog.Adapter

  def describe_tree do
    [supervisor(Cog.Adapters.Test.Supervisor, [])]
  end

  def lookup_room(_) do
    {:error, :not_implemented}
  end

  def lookup_user(_) do
    {:error, :not_implemented}
  end

  def direct_message(_id, _message) do
    {:error, :not_implemented}
  end

  def message(_room, _message) do
    {:error, :not_implemented}
  end

  def last_message(clear \\ false) do
    Cog.Adapters.Test.Recorder.last_message(clear)
  end

  def last_response(clear \\ false) do
    Cog.Adapters.Test.Recorder.last_response(clear)
  end

end
