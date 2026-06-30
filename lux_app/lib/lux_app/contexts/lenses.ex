defmodule LuxApp.Contexts.Lenses do
  @moduledoc """
  The Lenses context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.Lens

  @doc """
  Returns the list of lenses with pagination and filtering.

  ## Examples

      iex> list_lenses(%{})
      {:ok, {[%Lens{}, ...], %Flop.Meta{}}}

  """
  @spec list_lenses(map()) :: {:ok, {[Lens.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_lenses(params) do
    Flop.validate_and_run(Lens, params, for: Lens)
  end

  @doc """
  Gets a single lens.

  Raises `Ecto.NoResultsError` if the Lens does not exist.

  ## Examples

      iex> get_lens!(123)
      %Lens{}

      iex> get_lens!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_lens!(Ecto.UUID.t()) :: Lens.t()
  def get_lens!(id), do: Repo.get!(Lens, id)

  @doc """
  Gets a single lens.

  Returns `nil` if the Lens does not exist.

  ## Examples

      iex> get_lens(123)
      %Lens{}

      iex> get_lens(456)
      nil

  """
  @spec get_lens(Ecto.UUID.t()) :: Lens.t() | nil
  def get_lens(id), do: Repo.get(Lens, id)

  @doc """
  Creates a lens.

  ## Examples

      iex> create_lens(%{field: value})
      {:ok, %Lens{}}

      iex> create_lens(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_lens(map()) :: {:ok, Lens.t()} | {:error, Ecto.Changeset.t()}
  def create_lens(attrs \\ %{}) do
    %Lens{}
    |> Lens.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lens.

  ## Examples

      iex> update_lens(lens, %{field: new_value})
      {:ok, %Lens{}}

      iex> update_lens(lens, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_lens(Lens.t(), map()) :: {:ok, Lens.t()} | {:error, Ecto.Changeset.t()}
  def update_lens(%Lens{} = lens, attrs) do
    lens
    |> Lens.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lens.

  ## Examples

      iex> delete_lens(lens)
      {:ok, %Lens{}}

      iex> delete_lens(lens)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_lens(Lens.t()) :: {:ok, Lens.t()} | {:error, Ecto.Changeset.t()}
  def delete_lens(%Lens{} = lens) do
    Repo.delete(lens)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lens changes.

  ## Examples

      iex> change_lens(lens)
      %Ecto.Changeset{data: %Lens{}}

  """
  @spec change_lens(Lens.t(), map()) :: Ecto.Changeset.t()
  def change_lens(%Lens{} = lens, attrs \\ %{}) do
    Lens.changeset(lens, attrs)
  end
end
