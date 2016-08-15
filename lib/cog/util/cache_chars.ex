defimpl String.Chars, for: Cog.Util.Cache do

  def to_string(%Cog.Util.Cache{pid: pid, name: name}) do
    "<cache: #{name} (#{inspect pid, pretty: true})>"
  end

end
