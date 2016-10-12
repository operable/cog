defmodule Cog.ExecutorHelpers do

  require Logger

  alias Cog.Command.Pipeline.Binder
  alias Cog.Command.Pipeline.ParserMeta
  alias Cog.Models.CommandOption
  alias Cog.Models.CommandOptionType
  alias Cog.Models.BundleVersion
  alias Piper.Command.Parser

  # TODO: document command_spec

  # NOTE: Only returns ONE INVOCATION, so doesn't really work for
  # pipelines just yet
  def unbound_invocation(text, command_spec \\ []) do
    {:ok, pipeline} = Parser.scan_and_parse(text, options(command_spec))
    pipeline |> Enum.to_list |> List.first
  end

  # NOTE: also returns just one invocation
  def bound_invocation(text, context, command_spec) do
    {:ok, bound} = text
    |> unbound_invocation(command_spec)
    |> Binder.bind(context)

    bound
  end

  ########################################################################

  defp options(command_spec),
    do: %Piper.Command.ParserOptions{resolver: resolver(command_spec)}

  defp resolver(command_spec) do
    fn(bundle, name) ->
      bundle = case bundle do
                 nil ->
                   "test-bundle"
                 _ ->
                   bundle
               end
      {:command, {bundle, name, parser_meta_from_spec([name: name,
                                                       bundle: bundle] ++ command_spec)}}
    end
  end

  defp parser_meta_from_spec(spec) do
    {:ok, version} = Version.parse("1.0.0")
    ParserMeta.new(Keyword.fetch!(spec, :bundle),
                   Keyword.fetch!(spec, :name),
                   %BundleVersion{version: version,
                                  id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                                  config_file: %{"cog_bundle_version" => Spanner.Config.current_config_version}},
                   Enum.map(Keyword.get(spec, :options, []), &option_from_spec/1),
                   Enum.map(Keyword.get(spec, :rules, []), &rule_from_text/1))
  end

  defp option_from_spec(spec) do
    %CommandOption{name: Keyword.fetch!(spec, :name),
                   required: Keyword.get(spec, :required, false),
                   type: Keyword.get(spec, :type, "string"),
                   option_type: %CommandOptionType{name: Keyword.get(spec, :type, "string")},
                   long_flag: Keyword.get(spec, :long_flag, Keyword.fetch!(spec, :name)),
                   short_flag: Keyword.get(spec, :short_flag, nil)}
  end

  defp rule_from_text(text) do
    {:ok, expr, _permissions} = Piper.Permissions.Parser.parse(text)
    %Cog.Models.Rule{parse_tree: Piper.Permissions.Parser.rule_to_json!(expr),
                     score: expr.score}
  end

end
