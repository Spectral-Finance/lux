defmodule LuxApp.Contexts.SignalSchemas do
  @moduledoc """
  The SignalSchemas context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.SignalSchema

  @doc """
  Returns the list of signal_schemas with pagination and filtering.

  ## Examples

      iex> list_signal_schemas(%{})
      {:ok, {[%SignalSchema{}, ...], %Flop.Meta{}}}

  """
  @spec list_signal_schemas(map()) ::
          {:ok, {[SignalSchema.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_signal_schemas(params) do
    Flop.validate_and_run(SignalSchema, params, for: SignalSchema)
  end

  @doc """
  Gets a single signal_schema.

  Raises `Ecto.NoResultsError` if the SignalSchema does not exist.

  ## Examples

      iex> get_signal_schema!(123)
      %SignalSchema{}

      iex> get_signal_schema!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_signal_schema!(Ecto.UUID.t()) :: SignalSchema.t()
  def get_signal_schema!(id), do: Repo.get!(SignalSchema, id)

  @doc """
  Gets a single signal_schema.

  Returns `nil` if the SignalSchema does not exist.

  ## Examples

      iex> get_signal_schema(123)
      %SignalSchema{}

      iex> get_signal_schema(456)
      nil

  """
  @spec get_signal_schema(Ecto.UUID.t()) :: SignalSchema.t() | nil
  def get_signal_schema(id), do: Repo.get(SignalSchema, id)

  @doc """
  Creates a signal_schema.

  ## Examples

      iex> create_signal_schema(%{field: value})
      {:ok, %SignalSchema{}}

      iex> create_signal_schema(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_signal_schema(map()) :: {:ok, SignalSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_signal_schema(attrs \\ %{}) do
    %SignalSchema{}
    |> SignalSchema.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a signal_schema.

  ## Examples

      iex> update_signal_schema(signal_schema, %{field: new_value})
      {:ok, %SignalSchema{}}

      iex> update_signal_schema(signal_schema, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_signal_schema(SignalSchema.t(), map()) ::
          {:ok, SignalSchema.t()} | {:error, Ecto.Changeset.t()}
  def update_signal_schema(%SignalSchema{} = signal_schema, attrs) do
    signal_schema
    |> SignalSchema.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a signal_schema.

  ## Examples

      iex> delete_signal_schema(signal_schema)
      {:ok, %SignalSchema{}}

      iex> delete_signal_schema(signal_schema)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_signal_schema(SignalSchema.t()) ::
          {:ok, SignalSchema.t()} | {:error, Ecto.Changeset.t()}
  def delete_signal_schema(%SignalSchema{} = signal_schema) do
    Repo.delete(signal_schema)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking signal_schema changes.

  ## Examples

      iex> change_signal_schema(signal_schema)
      %Ecto.Changeset{data: %SignalSchema{}}

  """
  @spec change_signal_schema(SignalSchema.t(), map()) :: Ecto.Changeset.t()
  def change_signal_schema(%SignalSchema{} = signal_schema, attrs \\ %{}) do
    SignalSchema.changeset(signal_schema, attrs)
  end
end
