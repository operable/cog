defmodule Carrier.CredentialStoreTest do
  use ExUnit.Case

  alias Carrier.CredentialStore
  alias Carrier.Credentials

  setup_all do
    scratch_dir = Path.join([File.cwd!(), "test", "scratch", "*"])
    on_exit fn ->
      for file <- Path.wildcard(scratch_dir), do: File.rm_rf(file)
    end
  end

  defp rb() do
    :random.uniform(255)
  end

  defp temp_dir!() do
    {f, s, t} = :os.timestamp()
    path = Path.join([File.cwd!(), "test", "scratch", "#{f}#{s}#{t}"])
    File.rm_rf!(path)
    path
  end

  defp scramble(path) do
    {:ok, f} = path
    |> String.to_char_list
    |> :file.open([:read, :write])

    :random.seed(:os.timestamp())
    :ok = :file.write(f, <<rb(), rb(), rb(), rb(), rb(), rb(), rb(), rb()>>)
    :file.close(f)
  end

  test "create new credentials store with new system credentials" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    {:ok, creds} = CredentialStore.lookup(db, :system, by: :tag)
    assert creds.id != nil
    {:ok, _} = CredentialStore.close(db)
    assert CredentialStore.validate!(credentials_root) == db_path
  end

  test "opening a corrupted store returns an error" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    CredentialStore.close(db)
    scramble(db_path)
    error_path = String.to_char_list(db_path)
    assert CredentialStore.open(db_path) == {:error, {:not_a_dets_file, error_path}}
  end

  test "looking up non-existent credentials returns nil" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    id = UUID.uuid4(:hex)
    assert CredentialStore.lookup(db, id) == {:ok, nil}
  end

  test "retrieved stored creds by tag" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    |> Credentials.tag(:bot)
    :ok = CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, :bot, by: :tag) == {:ok, creds}
  end

  test "overwriting existing tagged cred fails" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    |> Credentials.tag(:bot)
    CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, :bot, by: :tag) == {:ok, creds}
    creds = Credentials.generate()
    |> Credentials.tag(:bot)
    {:error, :tag_exists} = CredentialStore.store(db, creds)
  end

  test "deleted tagged cred is irretrieveable" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    |> Credentials.tag(:bot)
    :ok = CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, :bot, by: :tag) == {:ok, creds}
    assert CredentialStore.delete(db, creds.id) == :ok
    assert CredentialStore.lookup(db, :bot, by: :tag) == {:ok, nil}
  end

  test "retrieved stored creds by id" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    :ok = CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, creds.id) == {:ok, creds}
  end

  test "overwriting existing cred fails" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, creds.id) == {:ok, creds}
    creds2 = Credentials.generate()
    creds2 = %{creds2 | id: creds.id}
    {:error, :exists} = CredentialStore.store(db, creds2)
  end

  test "deleted cred is irretrieveable" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    :ok = CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, creds.id) == {:ok, creds}
    assert CredentialStore.delete(db, creds.id) == :ok
    assert CredentialStore.lookup(db, creds.id) == {:ok, nil}
  end

  test "deletes are persistent" do
    credentials_root = temp_dir!
    db_path = CredentialStore.validate!(credentials_root)
    {:ok, db} = CredentialStore.open(db_path)
    creds = Credentials.generate()
    :ok = CredentialStore.store(db, creds)
    assert CredentialStore.lookup(db, creds.id) == {:ok, creds}
    assert CredentialStore.delete(db, creds.id) == :ok
    {:ok, _} = CredentialStore.close(db)
    {:ok, db} = CredentialStore.open(db_path)
    assert CredentialStore.lookup(db, creds.id) == {:ok, nil}
  end


end
