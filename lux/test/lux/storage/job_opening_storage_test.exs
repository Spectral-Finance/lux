defmodule Lux.Storage.JobOpeningStorageTest do
  use ExUnit.Case, async: true
  alias Lux.Storage.JobOpeningStorage
  alias Lux.Storage.Schemas.JobOpening
  alias Lux.Repo

  setup do
    # Start the sandbox for this test process
    Ecto.Adapters.SQL.Sandbox.mode(Lux.Repo, :manual)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Lux.Repo)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.checkin(Lux.Repo)
    end)

    # Insert some test data
    {:ok, job1} =
      JobOpeningStorage.store_job(%{
        name: "Software Engineer",
        description: "We are looking for a software engineer",
        status: "open",
        company_contract_address: "0x123f681646d4a755815f9cb19e1acc8565a0c2ac"
      })

    {:ok, job2} =
      JobOpeningStorage.store_job(%{
        name: "Product Manager",
        description: "We are looking for a product manager",
        status: "closed",
        company_contract_address: "0x456f681646d4a755815f9cb19e1acc8565a0c2ac"
      })

    {:ok, job3} =
      JobOpeningStorage.store_job(%{
        name: "Data Scientist",
        description: "We are looking for a data scientist",
        status: "open",
        company_contract_address: "0x789f681646d4a755815f9cb19e1acc8565a0c2ac"
      })

    %{job1: job1, job2: job2, job3: job3}
  end

  describe "store_job/1" do
    test "stores a new job opening" do
      attrs = %{
        name: "UX Designer",
        description: "We are looking for a UX designer",
        status: "open",
        company_contract_address: "0x321f681646d4a755815f9cb19e1acc8565a0c2ac"
      }

      assert {:ok, job} = JobOpeningStorage.store_job(attrs)
      assert job.name == "UX Designer"
      assert job.description == "We are looking for a UX designer"
      assert job.status == "open"
      assert job.company_contract_address == "0x321f681646d4a755815f9cb19e1acc8565a0c2ac"
    end

    test "returns error with invalid data" do
      attrs = %{
        description: "We are looking for a UX designer",
        status: "invalid"
      }

      assert {:error, changeset} = JobOpeningStorage.store_job(attrs)
      refute changeset.valid?
    end
  end

  describe "all_jobs/0" do
    test "retrieves all job openings", %{job1: job1, job2: job2, job3: job3} do
      jobs = JobOpeningStorage.all_jobs()
      assert length(jobs) >= 3

      ids = Enum.map(jobs, & &1.id)
      assert job1.id in ids
      assert job2.id in ids
      assert job3.id in ids
    end
  end

  describe "open_jobs/0" do
    test "retrieves all open job openings", %{job1: job1, job3: job3} do
      jobs = JobOpeningStorage.open_jobs()

      ids = Enum.map(jobs, & &1.id)
      assert job1.id in ids
      assert job3.id in ids
      assert length(jobs) >= 2
    end
  end

  describe "closed_jobs/0" do
    test "retrieves all closed job openings", %{job2: job2} do
      jobs = JobOpeningStorage.closed_jobs()

      ids = Enum.map(jobs, & &1.id)
      assert job2.id in ids
      assert length(jobs) >= 1
    end
  end

  describe "jobs_by_name/1" do
    test "retrieves job openings by name", %{job1: job1} do
      jobs = JobOpeningStorage.jobs_by_name("Software")

      ids = Enum.map(jobs, & &1.id)
      assert job1.id in ids
      assert length(jobs) >= 1
    end

    test "returns empty list when no jobs match" do
      jobs = JobOpeningStorage.jobs_by_name("nonexistent job")
      assert jobs == []
    end
  end

  describe "update_job/2" do
    test "updates a job opening", %{job1: job1} do
      attrs = %{
        name: "Senior Software Engineer",
        company_contract_address: "0xUpdated681646d4a755815f9cb19e1acc8565a0c2ac"
      }

      assert {:ok, updated} = JobOpeningStorage.update_job(job1.id, attrs)
      assert updated.name == "Senior Software Engineer"
      assert updated.company_contract_address == "0xUpdated681646d4a755815f9cb19e1acc8565a0c2ac"
      assert updated.description == job1.description
      assert updated.status == job1.status
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} = JobOpeningStorage.update_job(Ecto.UUID.generate(), %{name: "New Name"})
    end

    test "returns error for invalid data", %{job1: job1} do
      assert {:error, changeset} = JobOpeningStorage.update_job(job1.id, %{status: "invalid"})
      refute changeset.valid?
    end
  end

  describe "close_job/1" do
    test "closes an open job opening", %{job1: job1} do
      assert {:ok, closed} = JobOpeningStorage.close_job(job1.id)
      assert closed.status == "closed"
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} = JobOpeningStorage.close_job(Ecto.UUID.generate())
    end
  end

  describe "reopen_job/1" do
    test "reopens a closed job opening", %{job2: job2} do
      assert {:ok, reopened} = JobOpeningStorage.reopen_job(job2.id)
      assert reopened.status == "open"
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} = JobOpeningStorage.reopen_job(Ecto.UUID.generate())
    end
  end

  describe "delete_job/1" do
    test "deletes a job opening", %{job3: job3} do
      assert {:ok, deleted} = JobOpeningStorage.delete_job(job3.id)
      assert deleted.id == job3.id
      assert is_nil(Lux.Storage.get(JobOpening, job3.id))
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} = JobOpeningStorage.delete_job(Ecto.UUID.generate())
    end
  end
end
