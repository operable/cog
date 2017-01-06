defmodule Cog.Events.PipelineEvent do
  @moduledoc """
  Encapsulates information about command pipeline execution
  events. Each event is a map; all events share a core set of fields,
  while each event sub-type will have an additional set of fields
  particular to that sub-type.

  # Common Fields

  * `pipeline_id`: The unique identifier of the pipeline emitting the
  event. Can be used to correlate events from the same pipeline
  instance.

  * `event`: label indicating which pipeline lifecycle event is being
  recorded.

  * `timestamp`: When the event was created, in UTC, as an ISO-8601
  extended-format string (e.g. `"2016-01-07T15:08:00.000000Z"`). For
  pipelines that execute in sub-second time, also see
  `elapsed_microseconds`.

  * `elapsed_microseconds`: Number of microseconds elapsed since
  beginning of pipeline execution to the creation of this event.

  # Event-specific Data

  Depending on the type of event, the map will contain additional
  different keys. These are detailed here for each event.

  ## `pipeline_initialized`

  * `command_text`: (String) the text of the entire pipeline, as typed by the
    user. No variables will have been interpolated or bound at this point.
  * `provider`: (String) the chat provider being used
  * `handle`: (String) the provider-specific chat handle of the user issuing the
    command.
  * `cog_user`: The Cog-specific username of the invoker of issuer of
    the command. May be different than the provider-specific handle.

  ## `command_dispatched`

  * `command_text`: (String) the text of the command being dispatched to a
    Relay. In contrast to `pipeline_initialized` above, here,
    variables _have_ been interpolated and bound. If the user
    submitted a pipeline of multiple commands, a `command_dispatched`
    event will be created for each discrete command.
  * `relay`: (String) the unique identifier of the Relay the command was
    dispatched to.
  * `cog_env`: (JSON string) the calling environment sent to the
    command. The value is presented formally as a string, not a map.

  ## `pipeline_succeeded`

  * `result`: (JSON string) the JSON structure that resulted from the
    successful completion of the entire pipeline. This is the raw data
    produced by the pipeline, prior to any template application. The
    value is presented formally as a string, not a list or map.

  ## `pipeline_failed`

  * `error`: (String) a symbolic name of the kind of error produced
  * `message`: (String) Additional information and detail about
    the error

  """

  import Cog.Events.Util

  @typedoc """
  One of the valid kinds of events that can be emitted by a pipeline
  """
  @type event_label :: :pipeline_initialized |
                       :command_dispatched |
                       :pipeline_succeeded |
                       :pipeline_failed

  @doc """
  Create a `pipeline_initialized` event
  """
  def initialized(pipeline_id, start, text, provider, cog_user, handle) do
    new(pipeline_id, :pipeline_initialized, start, %{command_text: text,
                                                     cog_user: cog_user,
                                                     provider: provider,
                                                     chat_handle: handle})
  end

  @doc """
  Create a `command_dispatched` event
  """
  def dispatched(pipeline_id, start, command, relay, cog_env) do
    new(pipeline_id, :command_dispatched, start, %{command_text: command,
                                                   relay: relay,
                                                   cog_env: Poison.encode!(cog_env)})
  end

  @doc """
  Create a `pipeline_succeeded` event
  """
  def succeeded(pipeline_id, start, result),
    do: new(pipeline_id, :pipeline_succeeded, start, %{result: Poison.encode!(result)})

  @doc """
  Create a `pipeline_failed` event
  """
  def failed(pipeline_id, start, error, message) do
    new(pipeline_id, :pipeline_failed, start, %{error: error,
                                                message: message})
  end

  # Centralize common event creation logic
  defp new(pipeline_id, event, start, extra_fields) do
    {now, elapsed_us} = case event do
                          :pipeline_initialized -> {start, 0}
                          _ ->
                            now = DateTime.utc_now()
                            {now, elapsed(start, now)}
                        end

    Map.merge(extra_fields,
              %{pipeline_id: pipeline_id,
                event: event,
                elapsed_microseconds: elapsed_us,
                timestamp: Calendar.ISO.to_string(now)})
  end

end
