defmodule Lux.Lenses.Dune.ExecuteQueryTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Dune.ExecuteQuery

  describe "after_focus/1" do
    test "returns execution_id and state on success" do
      response = %{"execution_id" => "01J_abc123", "state" => "QUERY_STATE_PENDING"}

      assert {:ok, %{execution_id: "01J_abc123", state: "QUERY_STATE_PENDING"}} =
               ExecuteQuery.after_focus(response)
    end

    test "returns error when API returns error field" do
      assert {:error, "Query not found"} =
               ExecuteQuery.after_focus(%{"error" => "Query not found"})
    end

    test "returns error for unexpected response shapes" do
      assert {:error, "Unexpected response from Dune: " <> _} =
               ExecuteQuery.after_focus(%{"weird" => "data"})
    end
  end

  describe "focus/2 input validation" do
    test "returns error when query_id is missing" do
      assert {:error, "Missing required parameter: query_id"} = ExecuteQuery.focus(%{})
    end
  end
end
