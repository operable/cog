defmodule Cog.Service.EC2Test do
  use ExUnit.Case, async: true
  import Cog.Services.EC2

  test "getting a tag pair with single input" do
    assert {"Name", "Bot"} = gather_tag_pair("Bot")
  end

  test "getting a tag pair with Key:Value input" do
    assert {"Elf", "Buddy"} = gather_tag_pair("Elf:Buddy")
  end

  test "getting a tag pair with Key:Value input containing :" do
    assert {"Elf", "Christmas:Buddy"} = gather_tag_pair("Elf:Christmas:Buddy")
  end
end
