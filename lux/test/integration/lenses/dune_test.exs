defmodule Lux.Integration.DuneTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Dune.ExecuteQuery
  alias Lux.Lenses.Dune.GetQueryResults

  @tag :skip # Skip by default as Dune requires an API key
  test "can execute query and get results from Dune Analytics" do
    # 1258228 is a public query on Dune (dex volume)
    assert {:ok, %{execution_id: execution_id}} = ExecuteQuery.focus(%{query_id: 1258228})
    assert is_binary(execution_id)

    # Note: in a real scenario we would wait for completion, 
    # but here we just check we can call the results endpoint
    assert {:ok, result} = GetQueryResults.focus(%{execution_id: execution_id})
    assert Map.has_key?(result, :status)
  end
end
