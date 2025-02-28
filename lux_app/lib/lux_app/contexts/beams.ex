defmodule LuxApp.Contexts.Beams do
  @moduledoc """
  The Beams context.
  """

  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.Beam

  @doc """
  Returns the list of beams with pagination and filtering.

  ## Examples

      iex> list_beams(%{})
      {:ok, {[%Beam{}, ...], %Flop.Meta{}}}

  """
  @spec list_beams(map()) :: {:ok, {[Beam.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_beams(params) do
    Flop.validate_and_run(Beam, params, for: Beam)
  end

  @doc """
  Gets a single beam.

  Raises `Ecto.NoResultsError` if the Beam does not exist.

  ## Examples

      iex> get_beam!(123)
      %Beam{}

      iex> get_beam!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_beam!(Ecto.UUID.t()) :: Beam.t()
  def get_beam!(id), do: Repo.get!(Beam, id)

  @doc """
  Gets a single beam.

  Returns `nil` if the Beam does not exist.

  ## Examples

      iex> get_beam(123)
      %Beam{}

      iex> get_beam(456)
      nil

  """
  @spec get_beam(Ecto.UUID.t()) :: Beam.t() | nil
  def get_beam(id), do: Repo.get(Beam, id)

  @doc """
  Creates a beam.

  ## Examples

      iex> create_beam(%{field: value})
      {:ok, %Beam{}}

      iex> create_beam(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_beam(map()) :: {:ok, Beam.t()} | {:error, Ecto.Changeset.t()}
  def create_beam(attrs \\ %{}) do
    %Beam{}
    |> Beam.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a beam.

  ## Examples

      iex> update_beam(beam, %{field: new_value})
      {:ok, %Beam{}}

      iex> update_beam(beam, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_beam(Beam.t(), map()) :: {:ok, Beam.t()} | {:error, Ecto.Changeset.t()}
  def update_beam(%Beam{} = beam, attrs) do
    beam
    |> Beam.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a beam.

  ## Examples

      iex> delete_beam(beam)
      {:ok, %Beam{}}

      iex> delete_beam(beam)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_beam(Beam.t()) :: {:ok, Beam.t()} | {:error, Ecto.Changeset.t()}
  def delete_beam(%Beam{} = beam) do
    Repo.delete(beam)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking beam changes.

  ## Examples

      iex> change_beam(beam)
      %Ecto.Changeset{data: %Beam{}}

  """
  @spec change_beam(Beam.t(), map()) :: Ecto.Changeset.t()
  def change_beam(%Beam{} = beam, attrs \\ %{}) do
    Beam.changeset(beam, attrs)
  end
end
