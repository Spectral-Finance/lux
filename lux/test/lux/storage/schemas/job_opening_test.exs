defmodule Lux.Storage.Schemas.JobOpeningTest do
  use ExUnit.Case, async: true
  alias Lux.Storage
  alias Lux.Storage.Schemas.JobOpening
  alias Lux.Repo

  setup do
    # Start the sandbox for this test process
    Ecto.Adapters.SQL.Sandbox.mode(Lux.Repo, :manual)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Lux.Repo)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.checkin(Lux.Repo)
    end)

    :ok
  end

  describe "changeset/2" do
    test "validates required fields" do
      changeset = JobOpening.changeset(%JobOpening{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).description
    end

    test "validates status values" do
      attrs = %{
        name: "Software Engineer",
        description: "We are looking for a software engineer",
        status: "invalid"
      }

      changeset = JobOpening.changeset(%JobOpening{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "creates valid changeset with all fields" do
      attrs = %{
        name: "Software Engineer",
        description: "We are looking for a software engineer",
        status: "open",
        company_contract_address: "0x123f681646d4a755815f9cb19e1acc8565a0c2ac"
      }

      changeset = JobOpening.changeset(%JobOpening{}, attrs)
      assert changeset.valid?
    end

    test "creates valid changeset with required fields only" do
      attrs = %{
        name: "Software Engineer",
        description: "We are looking for a software engineer"
      }

      changeset = JobOpening.changeset(%JobOpening{}, attrs)
      assert changeset.valid?
    end
  end

  describe "storage operations" do
    test "stores and retrieves job openings" do
      attrs = %{
        name: "Software Engineer",
        description: "We are looking for a software engineer",
        status: "open",
        company_contract_address: "0x123f681646d4a755815f9cb19e1acc8565a0c2ac"
      }

      assert {:ok, job} = Storage.store(JobOpening, attrs)
      assert job.name == "Software Engineer"
      assert job.description == "We are looking for a software engineer"
      assert job.status == "open"
      assert job.company_contract_address == "0x123f681646d4a755815f9cb19e1acc8565a0c2ac"

      # Retrieve by ID
      retrieved = Storage.get(JobOpening, job.id)
      assert retrieved.id == job.id
      assert retrieved.name == "Software Engineer"
      assert retrieved.company_contract_address == "0x123f681646d4a755815f9cb19e1acc8565a0c2ac"

      # Update
      {:ok, updated} = Storage.update(job, %{status: "closed"})
      assert updated.status == "closed"

      # Query
      import Ecto.Query
      query = from j in JobOpening, where: j.status == "closed"
      results = Storage.query(query)
      assert length(results) >= 1
    end
  end

  # Helper function to extract error messages from a changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
