defmodule LuxApp.Contexts.Prisms do
  @moduledoc """
  The Prisms context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.Prism

  @doc """
  Returns the list of prisms with pagination and filtering.

  ## Examples

      iex> list_prisms(%{})
      {:ok, {[%Prism{}, ...], %Flop.Meta{}}}

  """
  @spec list_prisms(map()) :: {:ok, {[Prism.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_prisms(params) do
    Flop.validate_and_run(Prism, params, for: Prism)
  end

  @doc """
  Gets a single prism.

  Raises `Ecto.NoResultsError` if the Prism does not exist.

  ## Examples

      iex> get_prism!(123)
      %Prism{}

      iex> get_prism!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_prism!(Ecto.UUID.t()) :: Prism.t()
  def get_prism!(id), do: Repo.get!(Prism, id)

  @doc """
  Gets a single prism.

  Returns `nil` if the Prism does not exist.

  ## Examples

      iex> get_prism(123)
      %Prism{}

      iex> get_prism(456)
      nil

  """
  @spec get_prism(Ecto.UUID.t()) :: Prism.t() | nil
  def get_prism(id), do: Repo.get(Prism, id)

  @doc """
  Creates a prism.

  ## Examples

      iex> create_prism(%{field: value})
      {:ok, %Prism{}}

      iex> create_prism(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_prism(map()) :: {:ok, Prism.t()} | {:error, Ecto.Changeset.t()}
  def create_prism(attrs \\ %{}) do
    %Prism{}
    |> Prism.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a prism.

  ## Examples

      iex> update_prism(prism, %{field: new_value})
      {:ok, %Prism{}}

      iex> update_prism(prism, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_prism(Prism.t(), map()) :: {:ok, Prism.t()} | {:error, Ecto.Changeset.t()}
  def update_prism(%Prism{} = prism, attrs) do
    prism
    |> Prism.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a prism.

  ## Examples

      iex> delete_prism(prism)
      {:ok, %Prism{}}

      iex> delete_prism(prism)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_prism(Prism.t()) :: {:ok, Prism.t()} | {:error, Ecto.Changeset.t()}
  def delete_prism(%Prism{} = prism) do
    Repo.delete(prism)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking prism changes.

  ## Examples

      iex> change_prism(prism)
      %Ecto.Changeset{data: %Prism{}}

  """
  @spec change_prism(Prism.t(), map()) :: Ecto.Changeset.t()
  def change_prism(%Prism{} = prism, attrs \\ %{}) do
    Prism.changeset(prism, attrs)
  end
end
