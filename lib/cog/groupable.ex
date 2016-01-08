defprotocol Groupable do
  @moduledoc """
  Things that can go into groups!
  """

  def add_to(member, group)

  def remove_from(member, group)

end
