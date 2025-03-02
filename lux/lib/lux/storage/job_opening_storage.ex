defmodule Lux.Storage.JobOpeningStorage do
  @moduledoc """
  Provides higher-level functions for working with job openings.
  """

  alias Lux.Storage
  alias Lux.Storage.Schemas.JobOpening
  import Ecto.Query

  @doc """
  Stores a new job opening.

  ## Parameters

  - `attrs` - The attributes to store

  ## Returns

  - `{:ok, job}` - The stored job opening
  - `{:error, changeset}` - The error changeset
  """
  @spec store_job(map()) :: {:ok, JobOpening.t()} | {:error, Ecto.Changeset.t()}
  def store_job(attrs) do
    Storage.store(JobOpening, attrs)
  end

  @doc """
  Retrieves all job openings.

  ## Returns

  - A list of job openings
  """
  @spec all_jobs() :: [JobOpening.t()]
  def all_jobs do
    Storage.all(JobOpening)
  end

  @doc """
  Retrieves all open job openings.

  ## Returns

  - A list of open job openings
  """
  @spec open_jobs() :: [JobOpening.t()]
  def open_jobs do
    query = from j in JobOpening, where: j.status == "open"
    Storage.query(query)
  end

  @doc """
  Retrieves all closed job openings.

  ## Returns

  - A list of closed job openings
  """
  @spec closed_jobs() :: [JobOpening.t()]
  def closed_jobs do
    query = from j in JobOpening, where: j.status == "closed"
    Storage.query(query)
  end

  @doc """
  Retrieves job openings by name.

  ## Parameters

  - `name` - The name to search for

  ## Returns

  - A list of job openings
  """
  @spec jobs_by_name(String.t()) :: [JobOpening.t()]
  def jobs_by_name(name) do
    query = from j in JobOpening, where: like(j.name, ^"%#{name}%")
    Storage.query(query)
  end

  @doc """
  Updates a job opening.

  ## Parameters

  - `id` - The ID of the job opening to update
  - `attrs` - The attributes to update

  ## Returns

  - `{:ok, job}` - The updated job opening
  - `{:error, changeset}` - The error changeset
  - `{:error, :not_found}` - If the job opening is not found
  """
  @spec update_job(binary(), map()) ::
          {:ok, JobOpening.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_job(id, attrs) do
    case Storage.get(JobOpening, id) do
      nil -> {:error, :not_found}
      job -> Storage.update(job, attrs)
    end
  end

  @doc """
  Closes a job opening.

  ## Parameters

  - `id` - The ID of the job opening to close

  ## Returns

  - `{:ok, job}` - The closed job opening
  - `{:error, changeset}` - The error changeset
  - `{:error, :not_found}` - If the job opening is not found
  """
  @spec close_job(binary()) ::
          {:ok, JobOpening.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def close_job(id) do
    update_job(id, %{status: "closed"})
  end

  @doc """
  Reopens a job opening.

  ## Parameters

  - `id` - The ID of the job opening to reopen

  ## Returns

  - `{:ok, job}` - The reopened job opening
  - `{:error, changeset}` - The error changeset
  - `{:error, :not_found}` - If the job opening is not found
  """
  @spec reopen_job(binary()) ::
          {:ok, JobOpening.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def reopen_job(id) do
    update_job(id, %{status: "open"})
  end

  @doc """
  Deletes a job opening.

  ## Parameters

  - `id` - The ID of the job opening to delete

  ## Returns

  - `{:ok, job}` - The deleted job opening
  - `{:error, changeset}` - The error changeset
  - `{:error, :not_found}` - If the job opening is not found
  """
  @spec delete_job(binary()) ::
          {:ok, JobOpening.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def delete_job(id) do
    case Storage.get(JobOpening, id) do
      nil -> {:error, :not_found}
      job -> Storage.delete(job)
    end
  end
end
