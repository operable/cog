defmodule Carrier.CredentialStore do

  alias Carrier.FileError
  alias Carrier.SecurityError
  alias Carrier.Credentials

  defstruct [:fd, :path]

  @db_name "carrier_credentials.db"
  @dets_options [{:estimated_no_objects, 64}, {:ram_file, true}]

  @doc """
  Returns validated path to credential store

  ## Exceptions
  * Carrier.FileError
  * Carrier.SecurityError
  """
  @spec validate!(String.t()) :: String.t() | no_return()
  def validate!(root) do
    db_path = Path.join(root, @db_name)
    if File.exists?(db_path) do
      if File.regular?(db_path) do
        ensure_correct_mode!(db_path, 0o100600)
        case :dets.is_dets_file(String.to_char_list(db_path)) do
          true ->
            db_path
          false ->
            raise FileError.new("#{db_path} is not a valid credential store")
          {:error, reason} ->
            raise FileError.new("#{inspect reason}")
        end
      else
        raise FileError.not_a_file(db_path)
      end
    else
      File.mkdir_p!(Path.dirname(db_path))
      db_path
    end
  end

  @doc "Opens a credential store in read/write mode"
  @spec open(String.t()) :: {:ok, %__MODULE__{}} | {:error, term()}
  def open(path) do
    case open_file(path) do
      {:ok, fd} ->
        enforce_correct_mode!(path, 0o10600)
        case maybe_init(fd, :dets.info(fd, :no_objects)) do
          {:ok, db} ->
            {:ok, %{db | path: path}}
          error ->
            error
        end
      error ->
        error
    end
  end

  @doc "Syncs and closes the store"
  @spec close(%__MODULE__{}) :: {:ok, %__MODULE__{}}
  def close(%__MODULE__{fd: nil}=db) do
    {:ok, db}
  end
  def close(%__MODULE__{fd: fd}=db) do
    :dets.sync(fd)
    :dets.close(fd)
    {:ok, %{db | fd: nil}}
  end

  @doc "Writes credentials to disk"
  @spec store(%__MODULE__{}, %Credentials{}) :: :ok | {:error, term()}
  def store(%__MODULE__{fd: fd}, %Credentials{tag: nil}=creds) do
    case :dets.lookup(fd, creds.id) do
      [] ->
        ensure_sync(:dets.insert(fd, {creds.id, creds}), fd)
      [_] ->
        {:error, :exists}
    end
  end
  def store(%__MODULE__{fd: fd}, %Credentials{tag: tag, id: id}=creds) do
    case :dets.lookup(fd, tag) do
      [] ->
        case ensure_sync(:dets.insert(fd, {tag, creds.id}), fd) do
          :ok ->
            ensure_sync(:dets.insert(fd, {creds.id, creds}), fd)
          error ->
            :dets.delete(fd, tag)
            error
        end
      [{_, ^id}] ->
        :dets.insert(fd, {creds.id, creds})
      [_] ->
        {:error, :tag_exists}
    end
  end

  @doc "Deletes a credential by id from disk"
  @spec delete(%__MODULE__{}, String.t()) :: :ok | {:error, term()}
  def delete(%__MODULE__{}=db, value) when is_binary(value) do
    delete(db, value, [by: :id])
  end

  @doc "Deletes a credential by id or tag from disk"
  @spec delete(%__MODULE__{}, atom() | String.t(), [{:by, :id}] | [{:by, :tag}]) :: :ok | {:error, term()}
  def delete(%__MODULE__{fd: fd}=db, value, opts) do
    case lookup(db, value, opts) do
      {:ok, nil} ->
        :ok
      {:ok, %Credentials{tag: nil}=creds} ->
        ensure_sync(:dets.delete(fd, creds.id), fd)
      {:ok, %Credentials{tag: tag}=creds} ->
        case ensure_sync(:dets.delete(fd, tag), fd) do
          :ok ->
            ensure_sync(:dets.delete(fd, creds.id), fd)
          error ->
            error
        end
      error ->
        error
    end
  end

  @doc "Looks up credentials by id"
  @spec lookup(%__MODULE__{}, String.t()) :: {:ok, %Credentials{}} | {:ok, nil} | {:error, term()}
  def lookup(%__MODULE__{}=db, value) when is_binary(value) do
    lookup(db, value, [by: :id])
  end

  @doc "Fetches credentials by id or tag"
  @spec lookup(%__MODULE__{}, atom() | String.t(), [{:by, :id}] | [{:by, :tag}]) :: {:ok, %Credentials{}} | {:ok, nil} | {:error, term()}
  def lookup(%__MODULE__{fd: fd}, value, [by: :id]) do
    case :dets.lookup(fd, value) do
      [{^value, creds}] ->
        {:ok, creds}
      [] ->
        {:ok, nil}
      error ->
        error
    end
  end
  def lookup(%__MODULE__{fd: fd}=db, value, [by: :tag]) do
    case :dets.lookup(fd, value) do
      [{^value, id}] ->
        lookup(db, id, by: :id)
      [] ->
        {:ok, nil}
      error ->
        error
    end
  end

  @spec maybe_init([char()], integer()) :: {:ok, %__MODULE__{}}
  defp maybe_init(fd, 0) do
    credentials = Credentials.generate()
    |> Credentials.tag(:system)
    :dets.insert(fd, {:system, credentials.id})
    :dets.insert(fd, {credentials.id, credentials})
    {:ok, %__MODULE__{fd: fd}}
  end
  defp maybe_init(fd, _) do
    {:ok, %__MODULE__{fd: fd}}
  end

  @spec ensure_correct_mode!(String.t(), pos_integer()) :: true | no_return()
  defp ensure_correct_mode!(path, path_mode) do
    stat = File.stat!(path)
    if stat.mode != path_mode do
      raise SecurityError.wrong_permission(path, path_mode, stat.mode)
    else
      true
    end
  end

  @spec enforce_correct_mode!(String.t(), pos_integer()) :: :ok | {:error, term()}
  defp enforce_correct_mode!(path, path_mode) do
    stat = File.stat!(path)
    stat = %{stat | mode: path_mode}
    File.write_stat!(path, stat)
  end

  @spec open_file(String.t()) :: {:ok, term()} | {:error, term()}
  defp open_file(path) do
    db_path = String.to_char_list(path)
    case :dets.open_file(db_path, @dets_options) do
      {:ok, fd} ->
        unless File.exists?(path) do
          :dets.sync(fd)
        end
        {:ok, fd}
      error ->
        error
    end
  end

  @spec ensure_sync(term(), term()) :: :ok | {:error, term()}
  defp ensure_sync(result, fd) do
    case :dets.sync(fd) do
      :ok ->
        result
      error ->
        error
    end
  end

end
