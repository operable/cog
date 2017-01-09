defmodule Cog.Util.TimeHelpers do

  def now do
    :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
  end

end
