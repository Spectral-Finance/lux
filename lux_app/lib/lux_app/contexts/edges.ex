defmodule LuxApp.Contexts.Edges do
  @moduledoc """
  The Edges context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.Edge

  @doc """
  Returns the list of edges with pagination and filtering.

  ## Examples

      iex> list_edges(%{})
      {:ok, {[%Edge{}, ...], %Flop.Meta{}}}

  """
  @spec list_edges(map()) :: {:ok, {[Edge.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_edges(params) do
    Flop.validate_and_run(Edge, params, for: Edge)
  end

  @doc """
  Returns the list of edges for a specific source with pagination and filtering.

  ## Examples

      iex> list_edges_by_source(source_id, source_type, %{})
      {:ok, {[%Edge{}, ...], %Flop.Meta{}}}

  """
  @spec list_edges_by_source(Ecto.UUID.t(), String.t(), map()) ::
          {:ok, {[Edge.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_edges_by_source(source_id, source_type, params) do
    query = from e in Edge, where: e.source_id == ^source_id and e.source_type == ^source_type
    Flop.validate_and_run(query, params, for: Edge)
  end

  @doc """
  Returns the list of edges for a specific target with pagination and filtering.

  ## Examples

      iex> list_edges_by_target(target_id, target_type, %{})
      {:ok, {[%Edge{}, ...], %Flop.Meta{}}}

  """
  @spec list_edges_by_target(Ecto.UUID.t(), String.t(), map()) ::
          {:ok, {[Edge.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_edges_by_target(target_id, target_type, params) do
    query = from e in Edge, where: e.target_id == ^target_id and e.target_type == ^target_type
    Flop.validate_and_run(query, params, for: Edge)
  end

  @doc """
  Gets a single edge.

  Raises `Ecto.NoResultsError` if the Edge does not exist.

  ## Examples

      iex> get_edge!(123)
      %Edge{}

      iex> get_edge!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_edge!(Ecto.UUID.t()) :: Edge.t()
  def get_edge!(id), do: Repo.get!(Edge, id)

  @doc """
  Gets a single edge.

  Returns `nil` if the Edge does not exist.

  ## Examples

      iex> get_edge(123)
      %Edge{}

      iex> get_edge(456)
      nil

  """
  @spec get_edge(Ecto.UUID.t()) :: Edge.t() | nil
  def get_edge(id), do: Repo.get(Edge, id)

  @doc """
  Creates a edge.

  ## Examples

      iex> create_edge(%{field: value})
      {:ok, %Edge{}}

      iex> create_edge(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_edge(map()) :: {:ok, Edge.t()} | {:error, Ecto.Changeset.t()}
  def create_edge(attrs \\ %{}) do
    %Edge{}
    |> Edge.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a edge.

  ## Examples

      iex> update_edge(edge, %{field: new_value})
      {:ok, %Edge{}}

      iex> update_edge(edge, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_edge(Edge.t(), map()) :: {:ok, Edge.t()} | {:error, Ecto.Changeset.t()}
  def update_edge(%Edge{} = edge, attrs) do
    edge
    |> Edge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a edge.

  ## Examples

      iex> delete_edge(edge)
      {:ok, %Edge{}}

      iex> delete_edge(edge)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_edge(Edge.t()) :: {:ok, Edge.t()} | {:error, Ecto.Changeset.t()}
  def delete_edge(%Edge{} = edge) do
    Repo.delete(edge)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking edge changes.

  ## Examples

      iex> change_edge(edge)
      %Ecto.Changeset{data: %Edge{}}

  """
  @spec change_edge(Edge.t(), map()) :: Ecto.Changeset.t()
  def change_edge(%Edge{} = edge, attrs \\ %{}) do
    Edge.changeset(edge, attrs)
  end
end
