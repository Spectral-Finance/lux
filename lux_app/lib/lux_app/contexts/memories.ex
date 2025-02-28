defmodule LuxApp.Contexts.Memories do
  @moduledoc """
  The Memories context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.Memory
  alias LuxApp.Schemas.MemoryEntry

  @doc """
  Returns the list of memories with pagination and filtering.

  ## Examples

      iex> list_memories(%{})
      {:ok, {[%Memory{}, ...], %Flop.Meta{}}}

  """
  @spec list_memories(map()) :: {:ok, {[Memory.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_memories(params) do
    Flop.validate_and_run(Memory, params, for: Memory)
  end

  @doc """
  Gets a single memory.

  Raises `Ecto.NoResultsError` if the Memory does not exist.

  ## Examples

      iex> get_memory!(123)
      %Memory{}

      iex> get_memory!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_memory!(Ecto.UUID.t()) :: Memory.t()
  def get_memory!(id), do: Repo.get!(Memory, id)

  @doc """
  Gets a single memory.

  Returns `nil` if the Memory does not exist.

  ## Examples

      iex> get_memory(123)
      %Memory{}

      iex> get_memory(456)
      nil

  """
  @spec get_memory(Ecto.UUID.t()) :: Memory.t() | nil
  def get_memory(id), do: Repo.get(Memory, id)

  @doc """
  Creates a memory.

  ## Examples

      iex> create_memory(%{field: value})
      {:ok, %Memory{}}

      iex> create_memory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_memory(map()) :: {:ok, Memory.t()} | {:error, Ecto.Changeset.t()}
  def create_memory(attrs \\ %{}) do
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a memory.

  ## Examples

      iex> update_memory(memory, %{field: new_value})
      {:ok, %Memory{}}

      iex> update_memory(memory, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_memory(Memory.t(), map()) :: {:ok, Memory.t()} | {:error, Ecto.Changeset.t()}
  def update_memory(%Memory{} = memory, attrs) do
    memory
    |> Memory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a memory.

  ## Examples

      iex> delete_memory(memory)
      {:ok, %Memory{}}

      iex> delete_memory(memory)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_memory(Memory.t()) :: {:ok, Memory.t()} | {:error, Ecto.Changeset.t()}
  def delete_memory(%Memory{} = memory) do
    Repo.delete(memory)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking memory changes.

  ## Examples

      iex> change_memory(memory)
      %Ecto.Changeset{data: %Memory{}}

  """
  @spec change_memory(Memory.t(), map()) :: Ecto.Changeset.t()
  def change_memory(%Memory{} = memory, attrs \\ %{}) do
    Memory.changeset(memory, attrs)
  end

  # Memory Entries

  @doc """
  Returns the list of memory entries with pagination and filtering.

  ## Examples

      iex> list_memory_entries(%{})
      {:ok, {[%MemoryEntry{}, ...], %Flop.Meta{}}}

  """
  @spec list_memory_entries(map()) ::
          {:ok, {[MemoryEntry.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_memory_entries(params) do
    Flop.validate_and_run(MemoryEntry, params, for: MemoryEntry)
  end

  @doc """
  Returns the list of memory entries for a specific memory with pagination and filtering.

  ## Examples

      iex> list_memory_entries_by_memory(memory_id, %{})
      {:ok, {[%MemoryEntry{}, ...], %Flop.Meta{}}}

  """
  @spec list_memory_entries_by_memory(Ecto.UUID.t(), map()) ::
          {:ok, {[MemoryEntry.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_memory_entries_by_memory(memory_id, params) do
    query = from e in MemoryEntry, where: e.memory_id == ^memory_id
    Flop.validate_and_run(query, params, for: MemoryEntry)
  end

  @doc """
  Gets a single memory entry.

  Raises `Ecto.NoResultsError` if the Memory entry does not exist.

  ## Examples

      iex> get_memory_entry!(123)
      %MemoryEntry{}

      iex> get_memory_entry!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_memory_entry!(Ecto.UUID.t()) :: MemoryEntry.t()
  def get_memory_entry!(id), do: Repo.get!(MemoryEntry, id)

  @doc """
  Creates a memory entry.

  ## Examples

      iex> create_memory_entry(%{field: value})
      {:ok, %MemoryEntry{}}

      iex> create_memory_entry(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_memory_entry(map()) :: {:ok, MemoryEntry.t()} | {:error, Ecto.Changeset.t()}
  def create_memory_entry(attrs \\ %{}) do
    %MemoryEntry{}
    |> MemoryEntry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a memory entry.

  ## Examples

      iex> update_memory_entry(memory_entry, %{field: new_value})
      {:ok, %MemoryEntry{}}

      iex> update_memory_entry(memory_entry, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_memory_entry(MemoryEntry.t(), map()) ::
          {:ok, MemoryEntry.t()} | {:error, Ecto.Changeset.t()}
  def update_memory_entry(%MemoryEntry{} = memory_entry, attrs) do
    memory_entry
    |> MemoryEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a memory entry.

  ## Examples

      iex> delete_memory_entry(memory_entry)
      {:ok, %MemoryEntry{}}

      iex> delete_memory_entry(memory_entry)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_memory_entry(MemoryEntry.t()) ::
          {:ok, MemoryEntry.t()} | {:error, Ecto.Changeset.t()}
  def delete_memory_entry(%MemoryEntry{} = memory_entry) do
    Repo.delete(memory_entry)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking memory entry changes.

  ## Examples

      iex> change_memory_entry(memory_entry)
      %Ecto.Changeset{data: %MemoryEntry{}}

  """
  @spec change_memory_entry(MemoryEntry.t(), map()) :: Ecto.Changeset.t()
  def change_memory_entry(%MemoryEntry{} = memory_entry, attrs \\ %{}) do
    MemoryEntry.changeset(memory_entry, attrs)
  end
end
