defmodule Cog.Models.EctoJson.Test do
  use ExUnit.Case
  alias Cog.Models.EctoJson

  defmodule NoJsonTest do
    use Ecto.Model

    schema "nope" do
      field :reason, :string
    end
  end

  defmodule ScalarTest do
    use Ecto.Model
    use Cog.Models.EctoJson

    schema "testing" do
      field :name, :string
      field :biography, :string
      field :email_address, :string
      field :twitter, :string
    end

    summary_fields [:id, :name]
    detail_fields [:id, :name, :biography]
  end

  defmodule MultiTest do
    use Ecto.Model
    use Cog.Models.EctoJson

    schema "multi" do
      field :name, :string
      has_many :scalars, ScalarTest
    end

    summary_fields [:id, :name]
    detail_fields [:id, :name, :scalars]
  end

  test "summary field metadata is present" do
    assert [:id, :name] = ScalarTest.__json_fields__(:summary)
  end

  test "detail field metadata is present" do
    assert [:id, :name, :biography] = ScalarTest.__json_fields__(:detail)
  end

  test "unrecognized render policy raises error" do
    expected = %RuntimeError{message:
                             "Unrecognized JSON rendering policy 'wtf' for #{ScalarTest}"}
    assert ^expected = catch_error(ScalarTest.__json_fields__(:wtf))
  end

  test "render hashes using only simple fields" do
    struct = %ScalarTest{name: "Dr. Evil",
                         biography: "The details of my life are inconsequential...",
                         email_address: "evil@evil.com",
                         twitter: "@MeatHelmets"}
    summary = %{id: nil,
                name: "Dr. Evil"}
    detail = %{id: nil,
               name: "Dr. Evil",
               biography: "The details of my life are inconsequential..."}

    assert ^summary = EctoJson.render(struct, policy: :summary)
    assert ^detail = EctoJson.render(struct, policy: :detail)
  end

  test "rendering lists of structs works" do
    structs = [%ScalarTest{name: "Dr. Evil",
                           biography: "The details of my life are inconsequential...",
                           email_address: "evil@evil.com",
                           twitter: "@MeatHelmets"},
               %ScalarTest{name: "Dark Helmet",
                           biography: "<redacted>",
                           email_address: "dark.helmet@sector5.corp.empire.com",
                           twitter: "@TheRealDarkHelmet"}]
    summary = [%{id: nil,
                 name: "Dr. Evil"},
               %{id: nil,
                 name: "Dark Helmet"}]
    detail = [%{id: nil,
                name: "Dr. Evil",
                biography: "The details of my life are inconsequential..."},
              %{id: nil,
                name: "Dark Helmet",
                biography: "<redacted>"}]
    assert ^summary = EctoJson.render(structs, policy: :summary)
    assert ^detail = EctoJson.render(structs, policy: :detail)
  end

  test "rendering structs that don't use EctoJson fails" do
    struct = %NoJsonTest{reason: "forgot to use EctoJson, duh!"}
    assert :undef = catch_error(EctoJson.render(struct, policy: :summary))
  end

  test "unfetched associations blow up" do
    struct = %MultiTest{name: "forgot to run preload, eh?"}
    assert %RuntimeError{} = catch_error(EctoJson.render(struct, policy: :detail))
  end

  test "fetched associations render" do
    struct = %MultiTest{name: "preloaded!",
                        scalars: [%ScalarTest{name: "Dr. Evil",
                                              biography: "The details of my life are inconsequential...",
                                              email_address: "evil@evil.com",
                                              twitter: "@MeatHelmets"},
                                  %ScalarTest{name: "Austin Powers",
                                              biography: "Yeah, baby!",
                                              email_address: "austin@austinpowers.com",
                                              twitter: "@Groovy"}]}
    summary = %{id: nil, name: "preloaded!"}
    detail = %{id: nil,
               name: "preloaded!",
               scalars: [%{id: nil, name: "Dr. Evil", biography: "The details of my life are inconsequential..."},
                         %{id: nil, name: "Austin Powers", biography: "Yeah, baby!"}]}

    assert ^summary = EctoJson.render(struct, policy: :summary)
    assert ^detail = EctoJson.render(struct, policy: :detail)
  end

  test "an envelope wraps processed data in a hash" do
    assert :data = EctoJson.render(:data)
    assert %{stuff: :data} = EctoJson.render(:data, envelope: :stuff)
    assert %{stuff: [:data]} = EctoJson.render([:data], envelope: :stuff)
  end

  test "an unwrapped detailed rendering is the default" do
    struct = %ScalarTest{name: "Dr. Evil",
                         biography: "The details of my life are inconsequential...",
                         email_address: "evil@evil.com",
                         twitter: "@MeatHelmets"}
    detail = %{id: nil,
               name: "Dr. Evil",
               biography: "The details of my life are inconsequential..."}

    assert ^detail = EctoJson.render(struct)
  end

  @tag :skip
  test "what if you declare a summary field that isn't actually a field?" do
    flunk "implement me"
  end

  @tag :skip
  test "what if you try to render a struct that doesn't use EctoJson / Ecto?" do
    flunk "implement me"
  end
end
