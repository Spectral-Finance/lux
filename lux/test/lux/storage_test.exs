defmodule Lux.StorageTest do
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

  describe "store/2" do
    test "stores data successfully" do
      attrs = %{
        name: "Software Engineer",
        description: "We are looking for a software engineer",
        status: "open",
        company_address: "123 Main St, San Francisco, CA 94105"
      }
      assert {:ok, record} = Storage.store(JobOpening, attrs)
      assert record.name == "Software Engineer"
      assert record.description == "We are looking for a software engineer"
      assert record.status == "open"
    end

    test "returns error with invalid data" do
      attrs = %{
        name: "Software Engineer",
        status: "invalid"
      }
      assert {:error, changeset} = Storage.store(JobOpening, attrs)
      assert "can't be blank" in errors_on(changeset).description
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "update/2" do
    test "updates data successfully" do
      {:ok, record} = Storage.store(JobOpening, %{
        name: "Original Job",
        description: "Original Description",
        status: "open"
      })
      assert {:ok, updated} = Storage.update(record, %{name: "Updated Job"})
      assert updated.name == "Updated Job"
      assert updated.description == "Original Description"
    end

    test "returns error with invalid data" do
      {:ok, record} = Storage.store(JobOpening, %{
        name: "Original Job",
        description: "Original Description",
        status: "open"
      })
      assert {:error, changeset} = Storage.update(record, %{description: nil})
      assert "can't be blank" in errors_on(changeset).description
    end
  end

  describe "get/2" do
    test "retrieves a record by ID" do
      {:ok, record} = Storage.store(JobOpening, %{
        name: "Test Job",
        description: "Test Description",
        status: "open"
      })
      assert retrieved = Storage.get(JobOpening, record.id)
      assert retrieved.id == record.id
      assert retrieved.name == "Test Job"
    end

    test "returns nil for non-existent ID" do
      assert is_nil(Storage.get(JobOpening, Ecto.UUID.generate()))
    end
  end

  describe "get_by/3" do
    test "retrieves a record by field value" do
      unique_name = "Unique Job #{:rand.uniform(1000)}"
      {:ok, record} = Storage.store(JobOpening, %{
        name: unique_name,
        description: "Test Description",
        status: "open"
      })
      assert retrieved = Storage.get_by(JobOpening, :name, unique_name)
      assert retrieved.id == record.id
    end

    test "returns nil for non-existent field value" do
      assert is_nil(Storage.get_by(JobOpening, :name, "Non-existent Job"))
    end
  end

  describe "all/1" do
    test "retrieves all records" do
      {:ok, _} = Storage.store(JobOpening, %{
        name: "Job 1",
        description: "Description 1",
        status: "open"
      })
      {:ok, _} = Storage.store(JobOpening, %{
        name: "Job 2",
        description: "Description 2",
        status: "closed"
      })

      records = Storage.all(JobOpening)
      assert length(records) >= 2
    end
  end

  describe "delete/1" do
    test "deletes a record" do
      {:ok, record} = Storage.store(JobOpening, %{
        name: "Delete Test",
        description: "Delete Description",
        status: "open"
      })
      assert {:ok, _} = Storage.delete(record)
      assert is_nil(Storage.get(JobOpening, record.id))
    end
  end

  describe "query/1" do
    test "executes a custom query" do
      {:ok, _} = Storage.store(JobOpening, %{
        name: "Query Test 1",
        description: "Query Description 1",
        status: "open"
      })
      {:ok, _} = Storage.store(JobOpening, %{
        name: "Query Test 2",
        description: "Query Description 2",
        status: "closed"
      })

      import Ecto.Query
      query = from j in JobOpening, where: like(j.name, "Query Test%")

      results = Storage.query(query)
      assert length(results) >= 2
    end
  end

  describe "transaction/1" do
    test "executes a successful transaction" do
      result = Storage.transaction(fn ->
        {:ok, record} = Storage.store(JobOpening, %{
          name: "Transaction Test",
          description: "Transaction Description",
          status: "open"
        })
        record
      end)

      assert {:ok, record} = result
      assert record.name == "Transaction Test"
    end

    test "rolls back a failed transaction" do
      unique_name = "Will Rollback #{:rand.uniform(1000)}"
      result = Storage.transaction(fn ->
        {:ok, _} = Storage.store(JobOpening, %{
          name: unique_name,
          description: "Rollback Description",
          status: "open"
        })
        Repo.rollback(:rollback)
      end)

      assert result == {:error, :rollback}
      assert is_nil(Storage.get_by(JobOpening, :name, unique_name))
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
