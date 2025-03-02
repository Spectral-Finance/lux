defmodule Lux.Storage do
  @moduledoc """
  A generic storage module that interfaces with Postgres using Ecto.

  This module provides basic CRUD operations for storing and retrieving data.
  """

  alias Lux.Repo

  @doc """
  Stores data in the database.

  ## Parameters

  - `schema_module` - The Ecto schema module to use
  - `attrs` - The attributes to store

  ## Returns

  - `{:ok, record}` - The stored record
  - `{:error, changeset}` - The error changeset
  """
  @spec store(module(), map()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def store(schema_module, attrs) do
    schema_module
    |> struct()
    |> schema_module.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates data in the database.

  ## Parameters

  - `record` - The record to update
  - `attrs` - The attributes to update

  ## Returns

  - `{:ok, record}` - The updated record
  - `{:error, changeset}` - The error changeset
  """
  @spec update(Ecto.Schema.t(), map()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(record, attrs) do
    record
    |> record.__struct__.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Retrieves a record by ID.

  ## Parameters

  - `schema_module` - The Ecto schema module to use
  - `id` - The ID of the record to retrieve

  ## Returns

  - The record if found
  - `nil` if not found
  """
  @spec get(module(), term()) :: Ecto.Schema.t() | nil
  def get(schema_module, id) do
    Repo.get(schema_module, id)
  end

  @doc """
  Retrieves a record by a specific field value.

  ## Parameters

  - `schema_module` - The Ecto schema module to use
  - `field` - The field to query by
  - `value` - The value to match

  ## Returns

  - The record if found
  - `nil` if not found
  """
  @spec get_by(module(), atom(), term()) :: Ecto.Schema.t() | nil
  def get_by(schema_module, field, value) do
    Repo.get_by(schema_module, [{field, value}])
  end

  @doc """
  Retrieves all records of a specific schema.

  ## Parameters

  - `schema_module` - The Ecto schema module to use

  ## Returns

  - A list of records
  """
  @spec all(module()) :: [Ecto.Schema.t()]
  def all(schema_module) do
    Repo.all(schema_module)
  end

  @doc """
  Deletes a record from the database.

  ## Parameters

  - `record` - The record to delete

  ## Returns

  - `{:ok, record}` - The deleted record
  - `{:error, changeset}` - The error changeset
  """
  @spec delete(Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(record) do
    Repo.delete(record)
  end

  @doc """
  Executes a custom query.

  ## Parameters

  - `query` - The Ecto query to execute

  ## Returns

  - The query results
  """
  @spec query(Ecto.Query.t()) :: [Ecto.Schema.t()]
  def query(query) do
    Repo.all(query)
  end

  @doc """
  Performs a transaction.

  ## Parameters

  - `fun` - The function to execute in the transaction

  ## Returns

  - The result of the transaction
  """
  @spec transaction(function()) :: {:ok, term()} | {:error, term()}
  def transaction(fun) do
    Repo.transaction(fun)
  end
end
