defmodule Cog.Repository.ChatProviders do

  @moduledoc """
  Returns the persistent state for a given chat provider
  """

  @type error :: Ecto.Changeset.error | atom

  alias Cog.Repo
  alias Cog.Models.ChatProvider

  @spec get_provider_state(binary()) :: nil | map()
  def get_provider_state(name, default \\ %{}) when is_binary(name) do
    case Repo.get_by!(ChatProvider, name: name) do
      nil ->
        nil
      provider ->
        provider.data || default
    end
  end

  @spec set_provider_state(binary(), map()) :: {:ok, map()} | {:error, [error]}
  def set_provider_state(name, state) when is_binary(name) and is_map(state) do
    provider = Repo.get_by!(ChatProvider, name: name)
    changeset = ChatProvider.changeset(provider, %{"data" => state})
    case Repo.update(changeset) do
      {:ok, updated} ->
        {:ok, updated.data}
      {:error, changeset} ->
        {:error, changeset.errors}
    end
  end

end
