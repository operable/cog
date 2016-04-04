defmodule CogTest do
  use ExUnit.Case

  test "all chat adapters really are chat adapters" do
    for {_name, adapter_module} <- Cog.chat_adapters do
      assert adapter_module.chat_adapter?
    end
  end

  test "all non-chat adapters really are not chat adapters" do
    for {_name, adapter_module} <- Cog.non_chat_adapters do
      refute adapter_module.chat_adapter?
    end
  end

  test "all adapter names are correct" do
    for {name, adapter_module} <- Cog.all_adapters do
      assert name == adapter_module.name
    end
  end

end
