defmodule Cog.Pipeline.DoneSignal do
  defstruct [:error, :invocation, :bundle_version_id, :template]

  def error?(%__MODULE__{error: nil}), do: false
  def error?(%__MODULE__{}), do: true
  def error?(_), do: false

  def done?(%__MODULE__{}), do: true
  def done?(_), do: false

end

defmodule Cog.Pipeline.DataSignal do
  defstruct [invocation: nil,
             template: nil,
             bundle_version_id: nil,
             position: nil,
             data: nil]


  def wrap(data) when is_map(data) do
    %__MODULE__{data: data}
  end

  def wrap(data, bundle_version_id, template) when is_map(data) do
    %__MODULE__{data: data, bundle_version_id: bundle_version_id, template: template}
  end

end

defmodule Cog.Pipeline.AbortSignal do
  defstruct [message: nil,
             cog_env: nil,
             invocation: nil,
             template: "abort"]

  def wrap(invocation, cog_env, message) do
    %__MODULE__{invocation: invocation, cog_env: cog_env, message: message}
  end

  def abort?(%__MODULE__{}), do: true
  def abort?(_), do: false

end
