defmodule Cog.Pipeline.PrepareError do

  @moduledoc ~s"""
  Indicates an error occurred preparing to execute a command pipeline.
  Examples of such error conditions include failure to create execution
  stage processes, failure to create output/error sink processes, and
  command pipeline parse errors.
  """

  @type prepare_action :: :create_stage | :create_output_sink | :create_error_sink
  @type pipeline_error :: {:error, term()}

  @typedoc ~s"""
  Custom exception struct

  ## Fields
  * `:id` - Request id of the inbound command execution request
  * `:action` - Name of the failing pipeline preparation step
  * `:error` - Concrete error tuple
  """

  @type error :: %__MODULE__{
    id: String.t,
    action: prepare_action,
    error: pipeline_error
  }
  defexception [:id, :action, :error]

  def message(%__MODULE__{}=error) do
    "Action #{error.action} failed for request #{error.id}: #{inspect error.error}"
  end

  def exception(opts) do
    %__MODULE__{id: Keyword.get(opts, :id),
                action: Keyword.get(opts, :action),
                error: Keyword.get(opts, :error)}
  end

end
