defmodule Util.HashTest do

  use ExUnit.Case

  alias Cog.Util.Hash

  test "compute hash of an empty list" do
    assert Hash.compute_hash([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  end

  test "compute hash of an empty hash" do
    assert Hash.compute_hash(%{}) == "1d576f473e30e1b5828ea271d2a25598d6c7db12c47112c1ade052e2a6293fac"
  end

  test "empty maps and lists have different hashes" do
    assert Hash.compute_hash([]) != Hash.compute_hash(%{})
  end

  test "compute hash a string" do
    assert Hash.compute_hash("this is a test") == "90175d33da92d5e4e83b50a3c0bf3e1ee913c13296bcc24f14675288734a2c2a"
  end

  test "compute hash of an integer" do
    assert Hash.compute_hash(123456) == "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
  end

  test "compute hash of a float" do
    assert Hash.compute_hash(123.456) == "52dad41684065ccf8dd86bc21e739e57c750e4e1305f759956b7373308023eae"
  end

  test "compute hash of an atom" do
    assert Hash.compute_hash(:blah) == "5ec063f76ca1c5fdd044cd8e9af7de1bf97d235148d7257e18df8033e8bab99b"
  end

  test "equivalent maps hash to the same value" do
    a = %{"a" => 123, "b" => 456}
    b = %{"b" => 456, "a" => 123}
    assert Hash.compute_hash(a) == Hash.compute_hash(b)
  end

  test "different hashes has to different values" do
    a = %{"how" => "now", "brown" => "cow"}
    b = Map.put(a, :foo, [123])
    assert Hash.compute_hash(a) != Hash.compute_hash(b)
  end

  test "nested data structures are computable" do
    a = [1, 2, 3, %{"a" => 1, "b" => 2, "c" => [4, 5, %{"c" => "a"}]}]
    b = [1, 2, 3, %{"c" => [4, 5, %{"c" => "a"}], "b" => 2, "a" => 1}]
    assert Hash.compute_hash(a) == Hash.compute_hash(b)
  end

  test "hashes of lists are order sensitive" do
    a = [1,2,3,4,5]
    b = [1,3,2,5,4]
    assert Hash.compute_hash(a) != Hash.compute_hash(b)
  end

end
