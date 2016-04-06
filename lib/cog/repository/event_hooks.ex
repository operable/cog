defmodule Cog.Repository.EventHooks do
  @moduledoc """
  Behavioral API for interacting with event hooks. Prefer these
  functions over direct manipulation with `Cog.Repo`.
  """

  alias Cog.Repo
  alias Cog.Models.EventHook

  @doc """
  Retrieve the definition of the given event hook. The given id must
  be a valid UUID.
  """
  @spec hook_definition(String.t) :: {:ok, %EventHook{}} | {:error, :not_found | :bad_id}
  def hook_definition(id) do
    if Cog.UUID.is_uuid?(id) do
      case Repo.get(EventHook, id) do
        %EventHook{} = hook ->
          {:ok, hook}
        nil ->
          {:error, :not_found}
      end
    else
      {:error, :bad_id}
    end
  end

  @doc """
  Create a new event hook given a map of attributes.
  """
  @spec new(Map.t) :: {:ok, %EventHook{}} | {:error, Ecto.Changeset.t}
  def new(attrs) do
    %EventHook{}
    |> EventHook.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieve all event hooks. Order is undefined.
  """
  @spec all :: [%EventHook{}]
  def all,
    do: Repo.all(EventHook)

  def delete(%EventHook{}=hook) do
    try do
      Repo.delete(hook)
    rescue
      Ecto.StaleModelError ->
        {:error, :not_found}
    end
  end

  def update(%EventHook{}=hook, attrs) do
    hook
    |> EventHook.changeset(attrs)
    |> Repo.update
  end

end
